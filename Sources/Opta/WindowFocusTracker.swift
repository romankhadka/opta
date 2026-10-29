import AppKit
import ApplicationServices
import OptaCore
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
    private var retryTasksByProcessIdentifier: [pid_t: Task<Void, Never>] = [:]

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

    /// Records a focus change that an accessibility notification reported.
    fileprivate func recordNotifiedFocus(windowID: UInt32, processIdentifier: pid_t) {
        guard FocusObservationPolicy.shouldRecordNotification(
            fromProcessIdentifier: processIdentifier,
            frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        ) else {
            logger.debug(
                "ignoring background focus window=\(windowID, privacy: .public) pid=\(processIdentifier, privacy: .public)"
            )
            return
        }

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
        guard let processIdentifier = processIdentifier(from: notification) else {
            return
        }

        retryTasksByProcessIdentifier.removeValue(forKey: processIdentifier)?.cancel()
        observationsByProcessIdentifier.removeValue(forKey: processIdentifier)?.invalidate()
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
        retryTasksByProcessIdentifier.removeValue(forKey: processIdentifier)?.cancel()
        attemptObservation(ofApplicationWithProcessIdentifier: processIdentifier, attempt: 0)
    }

    /// A just-launched application refuses both the notification registration
    /// and the focused-window read until it is ready. Giving up there left its
    /// windows out of the recency log, and they sorted behind every recorded
    /// window. The attempt repeats while the application stays frontmost.
    private func attemptObservation(ofApplicationWithProcessIdentifier processIdentifier: pid_t, attempt: Int) {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, Self.accessibilityMessagingTimeout)

        let observation = observationsByProcessIdentifier[processIdentifier] ??
            ApplicationFocusObservation(processIdentifier: processIdentifier, tracker: self)
        observationsByProcessIdentifier[processIdentifier] = observation
        let applicationAnswered = observation?.registerPendingNotifications(on: applicationElement) ?? true

        let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let focusedWindowRead = applicationAnswered ? readFocusedWindow(of: applicationElement) : .notReady
        // The first attempt follows an activation, so the application is the
        // one the user just moved to. A retry runs later, when the user may
        // have moved on; recording it then would rank it above their window.
        if case .window(let windowID) = focusedWindowRead,
           attempt == 0 || processIdentifier == frontmostProcessIdentifier {
            logger.debug("focused window=\(windowID, privacy: .public) attempt=\(attempt, privacy: .public)")
            onWindowFocused(windowID)
        }

        guard FocusObservationPolicy.shouldRetry(
            attempt: attempt,
            registrationIsComplete: observation?.registrationIsComplete ?? false,
            focusedWindowRead: focusedWindowRead,
            isFrontmost: processIdentifier == frontmostProcessIdentifier
        ) else {
            return
        }

        retryTasksByProcessIdentifier[processIdentifier] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: FocusObservationPolicy.retryInterval)
            } catch {
                return
            }

            // A newer activation can cancel this task after its sleep ended
            // but before it resumed; it must not clear the newer task then.
            guard !Task.isCancelled, let self else {
                return
            }

            retryTasksByProcessIdentifier[processIdentifier] = nil
            attemptObservation(ofApplicationWithProcessIdentifier: processIdentifier, attempt: attempt + 1)
        }
    }

    private func readFocusedWindow(of applicationElement: AXUIElement) -> FocusedWindowRead {
        var rawFocusedWindow: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedWindowAttribute as CFString,
            &rawFocusedWindow
        )

        guard copyResult == .success else {
            return copyResult == .cannotComplete ? .notReady : .none
        }

        guard let rawFocusedWindow,
              CFGetTypeID(rawFocusedWindow) == AXUIElementGetTypeID(),
              let windowID = accessibilityWindowNumber(for: rawFocusedWindow as! AXUIElement) else {
            return .none
        }

        return .window(windowID)
    }
}

/// One application's registered accessibility observer. Kept per process so
/// terminated apps release their observer and run loop source.
@MainActor
private final class ApplicationFocusObservation {
    // Focused-window covers keyboard focus moving between windows; main-window
    // covers apps that update only the main window (e.g. clicking a window
    // without giving it keyboard focus). record() dedupes when both fire for
    // the same switch.
    private static let notificationNames = [
        kAXFocusedWindowChangedNotification,
        kAXMainWindowChangedNotification,
    ]

    private let observer: AXObserver
    private let context: UnsafeMutableRawPointer
    private var pendingNotificationNames = notificationNames

    var registrationIsComplete: Bool {
        pendingNotificationNames.isEmpty
    }

    /// Returns nil only when the observer itself cannot be created.
    init?(processIdentifier: pid_t, tracker: WindowFocusTracker) {
        var observer: AXObserver?
        guard AXObserverCreate(processIdentifier, focusObserverCallback, &observer) == .success,
              let observer else {
            return nil
        }

        self.observer = observer
        context = Unmanaged.passUnretained(tracker).toOpaque()
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Registers each notification the application has not accepted yet, and
    /// returns false when the application did not answer.
    ///
    /// An application that is still launching answers `cannotComplete`, often
    /// only after the messaging timeout. Every other request in the same
    /// attempt would wait out the timeout too, on the main thread, so the
    /// attempt stops at the first one. A notification the application does
    /// not support never will be, so that one is dropped.
    func registerPendingNotifications(on applicationElement: AXUIElement) -> Bool {
        var stillPendingNames: [String] = []
        defer { pendingNotificationNames = stillPendingNames }

        for (index, name) in pendingNotificationNames.enumerated() {
            switch AXObserverAddNotification(observer, applicationElement, name as CFString, context) {
            case .success, .notificationAlreadyRegistered, .notificationUnsupported, .notImplemented:
                continue
            case .cannotComplete:
                stillPendingNames.append(contentsOf: pendingNotificationNames[index...])
                return false
            default:
                stillPendingNames.append(name)
            }
        }

        return true
    }

    func invalidate() {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}

// Fires on the main run loop; the source is added to the main run loop above.
private let focusObserverCallback: AXObserverCallback = { _, element, _, context in
    var processIdentifier: pid_t = 0
    guard let context,
          AXUIElementGetPid(element, &processIdentifier) == .success,
          let windowID = accessibilityWindowNumber(for: element) else {
        return
    }

    let tracker = Unmanaged<WindowFocusTracker>.fromOpaque(context).takeUnretainedValue()
    MainActor.assumeIsolated {
        tracker.recordNotifiedFocus(windowID: windowID, processIdentifier: processIdentifier)
    }
}
