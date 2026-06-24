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
        guard let accessibilityWindow = findWindow(matching: window, in: accessibilityApplication) else {
            application.activate(options: [])
            return true
        }

        application.activate(options: [])
        AXUIElementSetAttributeValue(
            accessibilityApplication,
            kAXFrontmostAttribute as CFString,
            kCFBooleanTrue
        )
        focus(accessibilityWindow, in: accessibilityApplication)
        AXUIElementPerformAction(accessibilityWindow, kAXRaiseAction as CFString)
        focus(accessibilityWindow, in: accessibilityApplication)

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

    private func findWindow(matching window: WindowSnapshot, in application: AXUIElement) -> AXUIElement? {
        var rawWindows: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            application,
            kAXWindowsAttribute as CFString,
            &rawWindows
        )

        guard copyResult == .success, let windows = rawWindows as? [AXUIElement] else {
            return nil
        }

        let candidates = windows.map { accessibilityWindow in
            AccessibilityWindowCandidate(
                window: accessibilityWindow,
                candidate: WindowActivationCandidate(
                    windowNumber: windowNumber(for: accessibilityWindow),
                    title: title(for: accessibilityWindow),
                    bounds: bounds(for: accessibilityWindow)
                )
            )
        }

        guard let match = WindowActivationMatcher.bestMatch(
            for: window,
            candidates: candidates.map(\.candidate)
        ) else {
            return nil
        }

        return candidates.first { $0.candidate == match }?.window
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

    private func title(for window: AXUIElement) -> String {
        var rawTitle: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &rawTitle
        )

        guard copyResult == .success, let title = rawTitle as? String else {
            return ""
        }

        return title
    }

    private func bounds(for window: AXUIElement) -> WindowBounds? {
        guard let position = pointAttribute(kAXPositionAttribute, for: window),
              let size = sizeAttribute(kAXSizeAttribute, for: window) else {
            return nil
        }

        return WindowBounds(
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        )
    }

    private func pointAttribute(_ attribute: String, for window: AXUIElement) -> CGPoint? {
        var rawPoint: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(window, attribute as CFString, &rawPoint)

        guard copyResult == .success,
              let rawPoint,
              CFGetTypeID(rawPoint) == AXValueGetTypeID() else {
            return nil
        }

        let pointValue = rawPoint as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(pointValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func sizeAttribute(_ attribute: String, for window: AXUIElement) -> CGSize? {
        var rawSize: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(window, attribute as CFString, &rawSize)

        guard copyResult == .success,
              let rawSize,
              CFGetTypeID(rawSize) == AXValueGetTypeID() else {
            return nil
        }

        let sizeValue = rawSize as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }

        return size
    }
}

private struct AccessibilityWindowCandidate {
    let window: AXUIElement
    let candidate: WindowActivationCandidate
}
