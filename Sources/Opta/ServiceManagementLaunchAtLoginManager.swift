import OptaCore
import ServiceManagement

final class ServiceManagementLaunchAtLoginManager: LaunchAtLoginManaging {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .notRegistered:
            .disabled
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            // The main app reports `.notFound` until Launch Services has indexed
            // the bundle (e.g. right after an install). Treat it as "not a login
            // item yet" so the menu still lets the user register, rather than a
            // dead "unavailable" toggle. A genuine failure surfaces when
            // `register()` throws.
            .disabled
        @unknown default:
            .unavailable
        }
    }

    func enable() throws {
        try service.register()
    }

    func disable() throws {
        try service.unregister()
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
