import ApplicationServices
import AppKit
import CoreGraphics
import IOKit.hid
import OptaCore

@MainActor
enum PermissionManager {
    static func requestKeyboardCapturePermissions() -> KeyboardCapturePermissionState {
        KeyboardCapturePermissionState(
            accessibilityGranted: requestAccessibilityPermission(),
            inputMonitoringGranted: requestInputMonitoringPermission()
        )
    }

    static var keyboardCapturePermissionState: KeyboardCapturePermissionState {
        KeyboardCapturePermissionState(
            accessibilityGranted: isAccessibilityTrusted,
            inputMonitoringGranted: isInputMonitoringTrusted
        )
    }

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringTrusted: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func requestAccessibilityPermission() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestInputMonitoringPermission() -> Bool {
        if isInputMonitoringTrusted {
            return true
        }

        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func requestScreenRecordingPermissionIfNeeded() {
        guard !CGPreflightScreenCaptureAccess() else {
            return
        }

        _ = CGRequestScreenCaptureAccess()
    }

    static func showKeyboardCaptureHelp(permissionState: KeyboardCapturePermissionState) {
        let alert = NSAlert()
        alert.messageText = "Opta needs keyboard capture permission"
        alert.informativeText = keyboardCaptureHelpText(permissionState: permissionState)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Later")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            openAccessibilitySettings()
        case .alertSecondButtonReturn:
            openInputMonitoringSettings()
        default:
            return
        }
    }

    static func openAccessibilitySettings() {
        openSystemSettings(anchor: "Privacy_Accessibility")
    }

    static func openInputMonitoringSettings() {
        openSystemSettings(anchor: "Privacy_ListenEvent")
    }

    static func openScreenRecordingSettings() {
        openSystemSettings(anchor: "Privacy_ScreenCapture")
    }

    private static func keyboardCaptureHelpText(permissionState: KeyboardCapturePermissionState) -> String {
        let missingPermissions = permissionState.missingPermissionNames.joined(separator: " and ")

        if missingPermissions.isEmpty {
            return "macOS did not allow Opta to install its keyboard event tap. Open Privacy & Security settings, confirm Opta is enabled for Accessibility and Input Monitoring, then relaunch Opta."
        }

        return "Enable Opta for \(missingPermissions) in System Settings > Privacy & Security, then relaunch Opta."
    }

    private static func openSystemSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
