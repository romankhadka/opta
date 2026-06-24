import AppKit
import CoreGraphics
import OptaCore

struct SystemWindowProvider: WindowProviding {
    func availableWindows() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        return windowInfo.compactMap { rawWindow in
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
                )
            )
        }
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
