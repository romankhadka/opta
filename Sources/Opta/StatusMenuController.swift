import AppKit
import OptaCore
import OSLog

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let logger = Logger.opta(category: "launch")
    private let statusItem: NSStatusItem
    private let launchAtLoginController: LaunchAtLoginController
    private let currentApplicationShortcutController: CurrentApplicationShortcutController
    private let onCurrentApplicationShortcutChanged: (Bool) -> Void
    private var launchAtLoginItem: NSMenuItem?
    private var currentApplicationShortcutItem: NSMenuItem?

    init(
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController(
            manager: ServiceManagementLaunchAtLoginManager()
        ),
        currentApplicationShortcutController: CurrentApplicationShortcutController = CurrentApplicationShortcutController(
            store: UserDefaultsCurrentApplicationShortcutStore()
        ),
        onCurrentApplicationShortcutChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.launchAtLoginController = launchAtLoginController
        self.currentApplicationShortcutController = currentApplicationShortcutController
        self.onCurrentApplicationShortcutChanged = onCurrentApplicationShortcutChanged
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

        let currentApplicationShortcutItem = NSMenuItem(
            title: "Cycle Current App (⌥`)",
            action: #selector(toggleCurrentApplicationShortcut),
            keyEquivalent: ""
        )
        self.currentApplicationShortcutItem = currentApplicationShortcutItem
        menu.addItem(currentApplicationShortcutItem)
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
                title: "Open Input Monitoring Settings",
                action: #selector(openInputMonitoringSettings),
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
        refreshCurrentApplicationShortcutMenuItem()

        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshLaunchAtLoginMenuItem()
        refreshCurrentApplicationShortcutMenuItem()
    }

    @objc
    private func toggleLaunchAtLogin() {
        let stateBeforeToggle = launchAtLoginController.menuState
        logger.debug("launch toggle begin state=\(String(describing: stateBeforeToggle), privacy: .public)")

        do {
            try launchAtLoginController.toggle()
            let stateAfterToggle = launchAtLoginController.menuState
            logger.debug("launch toggle ok state=\(String(describing: stateAfterToggle), privacy: .public)")
            refreshLaunchAtLoginMenuItem()

            // A fresh registration usually needs the user to approve Opta under
            // System Settings > General > Login Items, so surface that panel.
            if stateAfterToggle == .requiresApproval {
                ServiceManagementLaunchAtLoginManager.openLoginItemsSettings()
            }
        } catch {
            logger.error("launch toggle failed error=\(error.localizedDescription, privacy: .public)")
            showLaunchAtLoginError(error)
        }
    }

    @objc
    private func toggleCurrentApplicationShortcut() {
        currentApplicationShortcutController.toggle()
        refreshCurrentApplicationShortcutMenuItem()
        onCurrentApplicationShortcutChanged(currentApplicationShortcutController.isEnabled)
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
    private func openInputMonitoringSettings() {
        PermissionManager.openInputMonitoringSettings()
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

        let (state, isEnabled, toolTip): (NSControl.StateValue, Bool, String?) = switch launchAtLoginController.menuState {
        case .off:
            (.off, true, nil)
        case .on:
            (.on, true, nil)
        case .requiresApproval:
            (.mixed, true, "Approve Opta in System Settings > General > Login Items.")
        case .unavailable:
            (.off, false, "Launch at Login is unavailable for this app bundle.")
        }

        launchAtLoginItem.state = state
        launchAtLoginItem.isEnabled = isEnabled
        launchAtLoginItem.toolTip = toolTip
    }

    private func refreshCurrentApplicationShortcutMenuItem() {
        guard let currentApplicationShortcutItem else {
            return
        }

        let isEnabled = currentApplicationShortcutController.isEnabled
        currentApplicationShortcutItem.state = isEnabled ? .on : .off
        currentApplicationShortcutItem.toolTip = isEnabled
            ? "Turn off if you type grave-accented characters with ⌥`."
            : nil
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
