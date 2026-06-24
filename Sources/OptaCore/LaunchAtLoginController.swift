public enum LaunchAtLoginStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

public enum LaunchAtLoginMenuState: Equatable, Sendable {
    case off
    case on
    case requiresApproval
    case unavailable

    public var checkboxTitle: String {
        switch self {
        case .on:
            "☑ Launch at Login"
        case .off, .requiresApproval, .unavailable:
            "☐ Launch at Login"
        }
    }
}

public protocol LaunchAtLoginManaging: AnyObject {
    var status: LaunchAtLoginStatus { get }

    func enable() throws
    func disable() throws
}

public final class LaunchAtLoginController {
    private let manager: LaunchAtLoginManaging

    public init(manager: LaunchAtLoginManaging) {
        self.manager = manager
    }

    public var status: LaunchAtLoginStatus {
        manager.status
    }

    public var menuState: LaunchAtLoginMenuState {
        switch manager.status {
        case .disabled:
            .off
        case .enabled:
            .on
        case .requiresApproval:
            .requiresApproval
        case .unavailable:
            .unavailable
        }
    }

    public func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try manager.enable()
        } else {
            try manager.disable()
        }
    }

    public func toggle() throws {
        switch menuState {
        case .off:
            try setEnabled(true)
        case .on, .requiresApproval:
            try setEnabled(false)
        case .unavailable:
            return
        }
    }
}
