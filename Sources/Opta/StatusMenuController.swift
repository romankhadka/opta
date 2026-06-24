import AppKit

@MainActor
final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Opta")
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Opta", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
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

        return menu
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
}
