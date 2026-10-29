import AppKit
import ApplicationServices
import OptaCore
import OSLog

/// Focuses the most recently used window when the frontmost application
/// closes its last window. See `FocusFollowsClosePolicy` for when it acts.
@MainActor
final class FocusFollowsCloseController {
    private static let accessibilityMessagingTimeout: Float = 0.25

    private let logger = Logger.opta(category: "focusFollowsClose")
    private let setting: UserDefaultsFocusFollowsCloseSetting
    private let cycler: WindowCycler
    private let activator: WindowActivator
    private let onWindowActivated: (UInt32) -> Void

    init(
        setting: UserDefaultsFocusFollowsCloseSetting,
        cycler: WindowCycler,
        activator: WindowActivator,
        onWindowActivated: @escaping (UInt32) -> Void
    ) {
        self.setting = setting
        self.cycler = cycler
        self.activator = activator
        self.onWindowActivated = onWindowActivated
    }

    func windowDidClose(windowID: UInt32, processIdentifier: pid_t) {
        guard
            setting.isEnabled,
            FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: processIdentifier,
                frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                applicationName: NSRunningApplication(processIdentifier: processIdentifier)?.localizedName
            ),
            applicationHasOtherWindows(processIdentifier, excluding: windowID) == false,
            let target = cycler.mostRecentWindow(excludingProcessIdentifier: processIdentifier)
        else {
            return
        }

        logger.debug(
            "closed last window=\(windowID, privacy: .public) of pid=\(processIdentifier, privacy: .public); focusing window=\(target.id, privacy: .public)"
        )
        if activator.activate(target) {
            onWindowActivated(target.id)
        }
    }

    /// Whether the application still shows a standard, unminimized window
    /// other than the closed one. The closed window can still be listed
    /// while it is torn down, so it is excluded by id. Returns nil when the
    /// application does not answer, so an unknown state never moves focus.
    private func applicationHasOtherWindows(_ processIdentifier: pid_t, excluding closedWindowID: UInt32) -> Bool? {
        let application = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(application, Self.accessibilityMessagingTimeout)

        var rawWindows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &rawWindows) == .success,
              let windows = rawWindows as? [AXUIElement] else {
            return nil
        }

        return windows.contains { window in
            AXUIElementSetMessagingTimeout(window, Self.accessibilityMessagingTimeout)
            return accessibilityWindowNumber(for: window) != closedWindowID &&
                stringAttribute(kAXSubroleAttribute, of: window) == kAXStandardWindowSubrole as String &&
                boolAttribute(kAXMinimizedAttribute, of: window) != true
        }
    }

    private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue) == .success else {
            return nil
        }

        return rawValue as? String
    }

    private func boolAttribute(_ attribute: String, of element: AXUIElement) -> Bool? {
        var rawValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &rawValue) == .success else {
            return nil
        }

        return rawValue as? Bool
    }
}

final class UserDefaultsFocusFollowsCloseSetting {
    private static let key = "focusFollowsCloseEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.key: true])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}
