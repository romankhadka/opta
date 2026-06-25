import Testing

@testable import OptaCore

@Suite("Launch at login")
struct LaunchAtLoginControllerTests {
    @Test("enabling registers the app for launch at login")
    func enablingRegistersLaunchAtLogin() throws {
        let manager = StubLaunchAtLoginManager(status: .disabled)
        let controller = LaunchAtLoginController(manager: manager)

        try controller.setEnabled(true)

        #expect(manager.status == .enabled)
        #expect(manager.enableCount == 1)
        #expect(manager.disableCount == 0)
        #expect(controller.menuState == .on)
    }

    @Test("disabling unregisters the app from launch at login")
    func disablingUnregistersLaunchAtLogin() throws {
        let manager = StubLaunchAtLoginManager(status: .enabled)
        let controller = LaunchAtLoginController(manager: manager)

        try controller.setEnabled(false)

        #expect(manager.status == .disabled)
        #expect(manager.enableCount == 0)
        #expect(manager.disableCount == 1)
        #expect(controller.menuState == .off)
    }

    @Test("toggling requires approval unregisters the app")
    func togglingRequiresApprovalUnregistersLaunchAtLogin() throws {
        let manager = StubLaunchAtLoginManager(status: .requiresApproval)
        let controller = LaunchAtLoginController(manager: manager)

        try controller.toggle()

        #expect(manager.status == .disabled)
        #expect(manager.disableCount == 1)
    }

    @Test("requires approval has its own menu state")
    func requiresApprovalHasMixedMenuState() {
        let manager = StubLaunchAtLoginManager(status: .requiresApproval)
        let controller = LaunchAtLoginController(manager: manager)

        #expect(controller.menuState == .requiresApproval)
    }

    @Test("menu state mirrors the manager status")
    func menuStateMirrorsManagerStatus() {
        #expect(LaunchAtLoginController(manager: StubLaunchAtLoginManager(status: .disabled)).menuState == .off)
        #expect(LaunchAtLoginController(manager: StubLaunchAtLoginManager(status: .enabled)).menuState == .on)
        #expect(
            LaunchAtLoginController(manager: StubLaunchAtLoginManager(status: .requiresApproval)).menuState
                == .requiresApproval
        )
        #expect(LaunchAtLoginController(manager: StubLaunchAtLoginManager(status: .unavailable)).menuState == .unavailable)
    }
}

private final class StubLaunchAtLoginManager: LaunchAtLoginManaging {
    var status: LaunchAtLoginStatus
    var enableCount = 0
    var disableCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func enable() throws {
        enableCount += 1
        status = .enabled
    }

    func disable() throws {
        disableCount += 1
        status = .disabled
    }
}
