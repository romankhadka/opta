import ApplicationServices
import AppKit
import CoreGraphics
import OptaCore
import OSLog

struct WindowActivator {
    // Bounds every synchronous accessibility call so a busy target app delays
    // activation by at most a second instead of the multi-second system
    // default, which would also block the next hotkey press.
    private static let accessibilityMessagingTimeout: Float = 1.0

    private let logger = Logger.opta(category: "activation")

    @discardableResult
    func activate(_ window: WindowSnapshot) -> Bool {
        let measurement = PerformanceMetrics.begin("WindowActivation")
        defer { PerformanceMetrics.end(measurement) }

        let processIdentifier = pid_t(window.processIdentifier)
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else {
            logger.error("missing app pid=\(window.processIdentifier, privacy: .public)")
            return false
        }

        let accessibilityApplication = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(accessibilityApplication, Self.accessibilityMessagingTimeout)
        let matchMeasurement = PerformanceMetrics.begin("WindowMatch")
        let matchingWindow = findWindow(matching: window, in: accessibilityApplication)
        PerformanceMetrics.end(matchMeasurement)

        guard let accessibilityWindow = matchingWindow else {
            logger.error(
                "no accessibility match id=\(window.id, privacy: .public) pid=\(window.processIdentifier, privacy: .public) title=\(window.displayTitle, privacy: .public)"
            )
            application.activate(options: [])
            return true
        }

        logger.debug(
            "activate match id=\(window.id, privacy: .public) pid=\(window.processIdentifier, privacy: .public) title=\(window.displayTitle, privacy: .public)"
        )
        let focusMeasurement = PerformanceMetrics.begin("WindowFocusActions")
        defer { PerformanceMetrics.end(focusMeasurement) }

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

        // An exact CoreGraphics id match is unambiguous and needs no title or
        // bounds traffic, so try it for every window before falling back to
        // scored matching. This keeps activation to a handful of accessibility
        // calls instead of several synchronous round-trips per open window.
        var windowNumbers: [UInt32?] = []
        windowNumbers.reserveCapacity(windows.count)
        for accessibilityWindow in windows {
            // The timeout set on the application element does not carry over
            // to its window elements, and both the raise action and the
            // fallback attribute reads below message the window directly.
            AXUIElementSetMessagingTimeout(accessibilityWindow, Self.accessibilityMessagingTimeout)
            let windowNumber = windowNumber(for: accessibilityWindow)
            if windowNumber == window.id {
                logger.debug("activate exact id match id=\(window.id, privacy: .public)")
                return accessibilityWindow
            }

            windowNumbers.append(windowNumber)
        }

        let candidates = windows.enumerated().map { order, accessibilityWindow in
            AccessibilityWindowCandidate(
                window: accessibilityWindow,
                candidate: WindowActivationCandidate(
                    windowNumber: windowNumbers[order],
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
        // Prefer the private mapping, which resolves the CoreGraphics window id
        // for any app and lets activation match the exact window even when two
        // windows of the same app share bounds and report no title.
        if let windowID = accessibilityWindowNumber(for: window) {
            return windowID
        }

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
        axValue(attribute, for: window) { value in
            var point = CGPoint.zero
            return AXValueGetValue(value, .cgPoint, &point) ? point : nil
        }
    }

    private func sizeAttribute(_ attribute: String, for window: AXUIElement) -> CGSize? {
        axValue(attribute, for: window) { value in
            var size = CGSize.zero
            return AXValueGetValue(value, .cgSize, &size) ? size : nil
        }
    }

    private func axValue<Value>(
        _ attribute: String,
        for window: AXUIElement,
        extract: (AXValue) -> Value?
    ) -> Value? {
        var rawValue: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(window, attribute as CFString, &rawValue)

        guard copyResult == .success,
              let rawValue,
              CFGetTypeID(rawValue) == AXValueGetTypeID() else {
            return nil
        }

        return extract(rawValue as! AXValue)
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
