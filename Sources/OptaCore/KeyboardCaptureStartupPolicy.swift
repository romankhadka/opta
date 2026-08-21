import Foundation

/// The action Opta must take to keep its keyboard event tap in step with the
/// permissions macOS currently grants.
public enum KeyboardCaptureStartupStep: Equatable, Sendable {
    /// Permissions are granted and no tap is installed: install one.
    case startTap
    /// Permissions were revoked under a live tap: tear the dead tap down so a
    /// later grant installs a fresh one.
    case stopTap
    /// Permissions are missing and the user has not been told yet.
    case showHelpAndWait
    /// Permissions are missing and the user already saw the help.
    case wait
    /// The tap is installed and permitted; nothing to do.
    case idle
}

/// Decides when to install, tear down, or wait for Opta's keyboard event tap.
///
/// Opta used to read the permission state once during launch and give up for
/// the rest of the process lifetime when it was missing. A user who granted
/// Accessibility or Input Monitoring from the help alert, or whose grants were
/// reset by `tccutil` under a running Opta, was left with a menu bar icon and a
/// shortcut that silently did nothing until they relaunched. Polling this
/// policy keeps the tap tied to the live permission state instead.
public struct KeyboardCaptureStartupPolicy: Sendable {
    /// How often the caller should re-evaluate the permission state. Both
    /// checks behind it are cheap process-local queries, so a short interval
    /// costs little and makes a grant feel immediate.
    public static let pollInterval: TimeInterval = 1

    public init() {}

    /// Returns the next action for the current permission and tap state.
    ///
    /// permissionState - What macOS grants Opta right now.
    /// tapIsRunning    - Whether a keyboard event tap is currently installed.
    /// helpWasShown    - Whether the user already saw the permission help for
    ///                   this outage.
    public func step(
        permissionState: KeyboardCapturePermissionState,
        tapIsRunning: Bool,
        helpWasShown: Bool
    ) -> KeyboardCaptureStartupStep {
        guard permissionState.canCaptureKeyboard else {
            if tapIsRunning {
                return .stopTap
            }

            return helpWasShown ? .wait : .showHelpAndWait
        }

        return tapIsRunning ? .idle : .startTap
    }
}
