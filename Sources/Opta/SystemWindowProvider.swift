import AppKit
import ApplicationServices
import CoreGraphics
import OptaCore
import OSLog

struct SystemWindowProvider: WindowProviding {
    private let logger = Logger.opta(category: "windowProvider")

    func availableWindows() -> [WindowSnapshot] {
        let measurement = PerformanceMetrics.begin("WindowDiscovery")
        defer { PerformanceMetrics.end(measurement) }

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        // Untitled windows are sometimes transient surfaces (cross-fade
        // snapshots or Chrome's status bubble) rather than real user windows,
        // so confirm they have a corresponding accessibility window with a
        // real-window subrole before treating them as cyclable. Merely being
        // in the accessibility window list is not enough: Chrome registers
        // its transient strips there too, but reports them as AXUnknown while
        // every real window reports AXStandardWindow (or AXDialog). Titled
        // windows skip this check entirely, since ghosts never carry a real
        // title.
        var accessibilityWindowIDsByProcess: [Int32: Set<UInt32>] = [:]

        func accessibilityWindowIDs(forProcessIdentifier processIdentifier: Int32) -> Set<UInt32> {
            if let cached = accessibilityWindowIDsByProcess[processIdentifier] {
                return cached
            }

            let application = AXUIElementCreateApplication(processIdentifier)
            // This runs synchronously on the hotkey path; the default
            // accessibility messaging timeout (several seconds) would let one
            // busy app freeze the switcher. Timing out treats the process's
            // untitled windows as ghosts for this invocation, which is the
            // cheaper failure.
            AXUIElementSetMessagingTimeout(application, 0.25)
            var rawWindows: CFTypeRef?
            let copyResult = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &rawWindows)

            let windowIDs: Set<UInt32> = if copyResult == .success, let windows = rawWindows as? [AXUIElement] {
                Set(
                    windows.compactMap { accessibilityWindow -> UInt32? in
                        // Window elements do not inherit the application
                        // element's messaging timeout.
                        AXUIElementSetMessagingTimeout(accessibilityWindow, 0.25)
                        guard hasRealWindowSubrole(accessibilityWindow) else {
                            return nil
                        }

                        return accessibilityWindowNumber(for: accessibilityWindow)
                    }
                )
            } else {
                []
            }

            accessibilityWindowIDsByProcess[processIdentifier] = windowIDs
            return windowIDs
        }

        let snapshots = windowInfo.enumerated().compactMap { recencyRank, rawWindow -> WindowSnapshot? in
            guard
                let windowNumber = number(rawWindow[kCGWindowNumber as String])?.uint32Value,
                let processIdentifier = number(rawWindow[kCGWindowOwnerPID as String])?.int32Value,
                processIdentifier != ownProcessIdentifier,
                let layer = number(rawWindow[kCGWindowLayer as String])?.intValue,
                let bounds = bounds(rawWindow[kCGWindowBounds as String])
            else {
                return nil
            }

            if let alpha = number(rawWindow[kCGWindowAlpha as String])?.doubleValue, alpha <= 0 {
                return nil
            }

            let applicationName = rawWindow[kCGWindowOwnerName as String] as? String ?? "Unknown App"
            let title = rawWindow[kCGWindowName as String] as? String ?? ""
            let isOnscreen = number(rawWindow[kCGWindowIsOnscreen as String])?.boolValue ?? true

            let hasAccessibilityWindow = !title.isEmpty ||
                accessibilityWindowIDs(forProcessIdentifier: processIdentifier).contains(windowNumber)

            if title.isEmpty, layer == 0, !hasAccessibilityWindow {
                logger.debug(
                    "dropping untitled ghost window id=\(windowNumber, privacy: .public) pid=\(processIdentifier, privacy: .public) app=\(applicationName, privacy: .public)"
                )
            }

            return WindowSnapshot(
                id: windowNumber,
                processIdentifier: processIdentifier,
                applicationName: applicationName,
                title: title,
                isOnscreen: isOnscreen,
                layer: layer,
                bounds: WindowBounds(
                    x: bounds.origin.x,
                    y: bounds.origin.y,
                    width: bounds.width,
                    height: bounds.height
                ),
                recencyRank: recencyRank,
                hasAccessibilityWindow: hasAccessibilityWindow
            )
        }

        // CGWindowList's own front-to-back order can lag behind the true
        // active application (e.g. Chrome raising an existing window to
        // handle a background "open URL" request from another app), so
        // correct it against NSWorkspace's authoritative frontmost app.
        return FrontmostApplicationCorrection.correcting(
            snapshots,
            frontmostProcessIdentifier: NSWorkspace.shared.frontmostApplication?.processIdentifier
        )
    }

    /// Whether the accessibility window carries a subrole real user windows
    /// report. A failed subrole read counts as real: dropping a genuine
    /// window on an accessibility hiccup is worse than briefly showing a
    /// transient one, and observed ghosts answer the query successfully
    /// (with AXUnknown).
    private func hasRealWindowSubrole(_ accessibilityWindow: AXUIElement) -> Bool {
        var rawSubrole: CFTypeRef?
        let copyResult = AXUIElementCopyAttributeValue(
            accessibilityWindow,
            kAXSubroleAttribute as CFString,
            &rawSubrole
        )

        guard copyResult == .success, let subrole = rawSubrole as? String else {
            return true
        }

        return subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String
    }

    private func number(_ rawValue: Any?) -> NSNumber? {
        rawValue as? NSNumber
    }

    private func bounds(_ rawValue: Any?) -> CGRect? {
        if let dictionary = rawValue as? NSDictionary {
            var bounds = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(dictionary as CFDictionary, &bounds) else {
                return nil
            }
            return bounds
        }

        guard let dictionary = rawValue as? [String: Any] else {
            return nil
        }

        return CGRect(
            x: number(dictionary["X"])?.doubleValue ?? 0,
            y: number(dictionary["Y"])?.doubleValue ?? 0,
            width: number(dictionary["Width"])?.doubleValue ?? 0,
            height: number(dictionary["Height"])?.doubleValue ?? 0
        )
    }
}
