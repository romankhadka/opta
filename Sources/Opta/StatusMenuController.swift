import AppKit
import OptaCore

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let launchAtLoginController: LaunchAtLoginController
    private var launchAtLoginItem: NSMenuItem?

    init(
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController(
            manager: ServiceManagementLaunchAtLoginManager()
        )
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.launchAtLoginController = launchAtLoginController
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Opta")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "Opta", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        self.launchAtLoginItem = launchAtLoginItem
        menu.addItem(launchAtLoginItem)

        menu.addItem(
            NSMenuItem(
                title: "Open Login Items Settings",
                action: #selector(openLoginItemsSettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())

        menu.addItem(
            NSMenuItem(
                title: "Open Accessibility Settings",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(
            NSMenuItem(
                title: "Open Screen Recording Settings",
                action: #selector(openScreenRecordingSettings),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Opta", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        refreshLaunchAtLoginMenuItem()

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLaunchAtLoginMenuItem()
    }

    @objc
    private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.toggle()
            refreshLaunchAtLoginMenuItem()

            if launchAtLoginController.menuState == .requiresApproval {
                ServiceManagementLaunchAtLoginManager.openLoginItemsSettings()
            }
        } catch {
            showLaunchAtLoginError(error)
        }
    }

    @objc
    private func openLoginItemsSettings() {
        ServiceManagementLaunchAtLoginManager.openLoginItemsSettings()
    }

    @objc
    private func openAccessibilitySettings() {
        PermissionManager.openAccessibilitySettings()
    }

    @objc
    private func openScreenRecordingSettings() {
        PermissionManager.openScreenRecordingSettings()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshLaunchAtLoginMenuItem() {
        guard let launchAtLoginItem else {
            return
        }

        switch launchAtLoginController.menuState {
        case .off:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = nil
        case .on:
            launchAtLoginItem.state = .on
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = nil
        case .requiresApproval:
            launchAtLoginItem.state = .mixed
            launchAtLoginItem.isEnabled = true
            launchAtLoginItem.toolTip = "Approve Opta in System Settings > General > Login Items."
        case .unavailable:
            launchAtLoginItem.state = .off
            launchAtLoginItem.isEnabled = false
            launchAtLoginItem.toolTip = "Launch at Login is unavailable for this app bundle."
        }
    }

    private func showLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
