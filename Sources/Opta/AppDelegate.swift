import AppKit
import OptaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowProvider = SystemWindowProvider()
    private let windowActivator = WindowActivator()
    private let overlayController = SwitcherOverlayController()
    private var keyboardEventTap: KeyboardEventTap?
    private var statusMenuController: StatusMenuController?
    private lazy var cycler = WindowCycler(provider: windowProvider)
    private lazy var coordinator = SwitcherCoordinator(cycler: cycler)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController()
        _ = PermissionManager.requestAccessibilityPermission()
        PermissionManager.requestScreenRecordingPermissionIfNeeded()

        let eventTap = KeyboardEventTap(
            onCycleAllApplications: { [weak self] in
                self?.cycleAllApplications()
            },
            onCycleCurrentApplication: { [weak self] in
                self?.cycleCurrentApplication()
            },
            onModifierRelease: { [weak self] in
                self?.commitSelection()
            }
        )

        keyboardEventTap = eventTap
        if !eventTap.start() {
            PermissionManager.showAccessibilityHelp()
        }
    }

    private func cycleAllApplications() {
        let session = coordinator.press(scope: .allApplications)
        show(session: session)
    }

    private func cycleCurrentApplication() {
        guard let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            overlayController.hide()
            return
        }

        let session = coordinator.press(
            scope: .currentApplication(processIdentifier: frontmostProcessIdentifier)
        )
        show(session: session)
    }

    private func show(session: WindowCycleSession) {
        guard !session.windows.isEmpty else {
            overlayController.hide()
            return
        }

        overlayController.show(session: session)
    }

    private func commitSelection() {
        let selectedWindow = coordinator.release()
        overlayController.hide()

        guard let selectedWindow else {
            return
        }

        windowActivator.activate(selectedWindow)
    }
}
