import ApplicationServices
import AppKit
import OptaCore
import OSLog

struct WindowActivator {
    private let logger = Logger(subsystem: "io.github.romankhadka.opta", category: "activation")

    @discardableResult
    func activate(_ window: WindowSnapshot) -> Bool {
        let processIdentifier = pid_t(window.processIdentifier)
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            logger.error("missing app pid=\(window.processIdentifier, privacy: .public)")
            return false
        }

        let accessibilityApplication = AXUIElementCreateApplication(processIdentifier)
        guard let accessibilityWindow = findWindow(matching: window, in: accessibilityApplication) else {
            logger.error(
                "no accessibility match id=\(window.id, privacy: .public) pid=\(window.processIdentifier, privacy: .public) title=\(window.displayTitle, privacy: .public)"
            )
            application.activate(options: [])
            return true
        }

        logger.debug(
            "activate match id=\(window.id, privacy: .public) pid=\(window.processIdentifier, privacy: .public) title=\(window.displayTitle, privacy: .public)"
        )
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

        let candidates = windows.enumerated().map { order, accessibilityWindow in
            AccessibilityWindowCandidate(
                window: accessibilityWindow,
                candidate: WindowActivationCandidate(
                    windowNumber: windowNumber(for: accessibilityWindow),
                    title: title(for: accessibilityWindow),
                    bounds: bounds(for: accessibilityWindow),
                    order: order
                )
            )
        }
        let targetOrder = windowOrder(for: window)

        logger.debug(
            "matching id=\(window.id, privacy: .public) targetOrder=\(targetOrder ?? -1, privacy: .public) title=\(window.displayTitle, privacy: .public) bounds=\(boundsDescription(window.bounds), privacy: .public)"
        )
        for candidate in candidates {
            logger.debug(
                "candidate order=\(candidate.candidate.order ?? -1, privacy: .public) number=\(candidate.candidate.windowNumber ?? 0, privacy: .public) title=\(candidate.candidate.title, privacy: .public) bounds=\(boundsDescription(candidate.candidate.bounds), privacy: .public)"
            )
        }

        guard let match = WindowActivationMatcher.bestMatch(
            for: window,
            candidates: candidates.map(\.candidate),
            targetOrder: targetOrder
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

    private func windowOrder(for window: WindowSnapshot) -> Int? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let windowIDs = windowInfo.compactMap { rawWindow -> UInt32? in
            guard
                let processIdentifier = rawWindow[kCGWindowOwnerPID as String] as? NSNumber,
                processIdentifier.int32Value == window.processIdentifier,
                let layer = rawWindow[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let windowNumber = rawWindow[kCGWindowNumber as String] as? NSNumber
            else {
                return nil
            }

            return windowNumber.uint32Value
        }

        return windowIDs.firstIndex(of: window.id)
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

    private func boundsDescription(_ bounds: WindowBounds?) -> String {
        guard let bounds else {
            return "nil"
        }

        return "x=\(Int(bounds.x)) y=\(Int(bounds.y)) w=\(Int(bounds.width)) h=\(Int(bounds.height))"
    }
}

private struct AccessibilityWindowCandidate {
    let window: AXUIElement
    let candidate: WindowActivationCandidate
}
