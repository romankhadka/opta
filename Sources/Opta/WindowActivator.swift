import ApplicationServices
import AppKit
import OptaCore

struct WindowActivator {
    @discardableResult
    func activate(_ window: WindowSnapshot) -> Bool {
        let processIdentifier = pid_t(window.processIdentifier)
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            return false
        }

        let accessibilityApplication = AXUIElementCreateApplication(processIdentifier)
        guard let accessibilityWindow = findWindow(number: window.id, in: accessibilityApplication) else {
            application.activate(options: [.activateAllWindows])
            return true
        }

        application.activate(options: [.activateAllWindows])
        focus(accessibilityWindow, in: accessibilityApplication)
        AXUIElementPerformAction(accessibilityWindow, kAXRaiseAction as CFString)

        return true
    }

    private func focus(_ window: AXUIElement, in application: AXUIElement) {
        AXUIElementSetAttributeValue(
            application,
            kAXMainWindowAttribute as CFString,
            window
        )
        AXUIElementSetAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            window
        )
    }

    private func findWindow(number windowNumber: UInt32, in application: AXUIElement) -> AXUIElement? {
        var rawWindows: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &rawWindows
        )

        guard copyResult == .success, let windows = rawWindows as? [AXUIElement] else {
            return nil
        }

        return windows.first { window in
            self.windowNumber(for: window) == windowNumber
        }
    }

    private func windowNumber(for window: AXUIElement) -> UInt32? {
        var rawWindowNumber: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            window,
            "AXWindowNumber" as CFString,
            &rawWindowNumber
        )

        guard copyResult == .success, let number = rawWindowNumber as? NSNumber else {
            return nil
        }

        return number.uint32Value
    }
}
