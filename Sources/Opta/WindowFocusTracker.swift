import AppKit
import ApplicationServices
import OSLog

/// Reports window focus changes as they happen, so recency ordering stays
/// correct for focus changes made outside Opta.
///
/// Observing only the frontmost window when the switcher is invoked loses
/// every intermediate focus change made since the previous invocation (Dock
/// clicks, Cmd+Tab, clicking another window of the same app). Those windows
/// then sort by the system's stacking order below all previously recorded
/// windows, offering stale windows ahead of ones the user just left. Watching
/// application activations and each app's focused-window changes keeps the
/// recency log ordered the way the user actually moved through windows.
@MainActor
final class WindowFocusTracker: NSObject {
    // A busy app must not stall the main thread while its focused window is
    // resolved; missing one observation is cheaper than a visible hang.
    private static let accessibilityMessagingTimeout: Float = 0.25

    private let logger = Logger.opta(category: "focusTracker")
    private let onWindowFocused: (UInt32) -> Void
    private var observationsByProcessIdentifier: [pid_t: ApplicationFocusObservation] = [:]

    init(onWindowFocused: @escaping (UInt32) -> Void) {
        self.onWindowFocused = onWindowFocused
    }

    func start() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            observeFocus(ofApplicationWithProcessIdentifier: frontmostApplication.processIdentifier)
        }
    }

    func recordFocus(windowID: UInt32) {
        onWindowFocused(windowID)
    }

    // NSWorkspace posts its notifications on the main thread, satisfying the
    // main-actor isolation the compiler cannot check across this ObjC entry.
    @objc private func applicationDidActivate(_ notification: Notification) {
        guard let processIdentifier = processIdentifier(from: notification),
              processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }

        observeFocus(ofApplicationWithProcessIdentifier: processIdentifier)
    }

    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let processIdentifier = processIdentifier(from: notification),
              let observation = observationsByProcessIdentifier.removeValue(forKey: processIdentifier) else {
            return
        }

        observation.invalidate()
    }

    private func processIdentifier(from notification: Notification) -> pid_t? {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return application?.processIdentifier
    }

    /// Ensures focused-window notifications are observed for the application
    /// and records its currently focused window. The immediate read matters
    /// because switching apps does not change the focused window *within*
    /// either app, so no accessibility notification fires for the switch.
    private func observeFocus(ofApplicationWithProcessIdentifier processIdentifier: pid_t) {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, Self.accessibilityMessagingTimeout)

        if observationsByProcessIdentifier[processIdentifier] == nil,
           let observation = ApplicationFocusObservation(
               processIdentifier: processIdentifier,
               applicationElement: applicationElement,
               tracker: self
           ) {
            observationsByProcessIdentifier[processIdentifier] = observation
        }

        recordFocusedWindow(of: applicationElement)
    }

    private func recordFocusedWindow(of applicationElement: AXUIElement) {
        var rawFocusedWindow: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &rawFocusedWindow
        )

        guard copyResult == .success,
              let rawFocusedWindow,
              CFGetTypeID(rawFocusedWindow) == AXUIElementGetTypeID(),
              let windowID = accessibilityWindowNumber(for: rawFocusedWindow as! AXUIElement) else {
            return
        }

        logger.debug("focused window=\(windowID, privacy: .public)")
        recordFocus(windowID: windowID)
    }
}

/// One application's registered accessibility observer. Kept per process so
/// terminated apps release their observer and run loop source.
@MainActor
private final class ApplicationFocusObservation {
    private let observer: AXObserver

    /// Returns nil when the observer cannot be created or no notification can
    /// be registered (app not accessibility-ready yet); the caller retries on
    /// the app's next activation.
    init?(processIdentifier: pid_t, applicationElement: AXUIElement, tracker: WindowFocusTracker) {
        var observer: AXObserver?
        guard AXObserverCreate(processIdentifier, focusObserverCallback, &observer) == .success,
              let observer else {
            return nil
        }

        let context = Unmanaged.passUnretained(tracker).toOpaque()
        // Focused-window covers keyboard focus moving between windows; main-
        // window covers apps that update only the main window (e.g. clicking
        // a window without giving it keyboard focus). record() dedupes when
        // both fire for the same switch.
        let notificationNames = [
            kAXFocusedWindowChangedNotification,
            kAXMainWindowChangedNotification,
        ]
        let registeredCount = notificationNames.count { name in
            AXObserverAddNotification(observer, applicationElement, name as CFString, context) == .success
        }

        guard registeredCount > 0 else {
            return nil
        }

        self.observer = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    func invalidate() {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}

// Fires on the main run loop; the source is added to the main run loop above.
private let focusObserverCallback: AXObserverCallback = { _, element, _, context in
    guard let context, let windowID = accessibilityWindowNumber(for: element) else {
        return
    }

    let tracker = Unmanaged<WindowFocusTracker>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        tracker.recordFocus(windowID: windowID)
    }
}
