import AppKit
import OptaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let windowProvider = SystemWindowProvider()
    private let windowActivator = WindowActivator()
    private let overlayController = SwitcherOverlayController()
    private var keyboardEventTap: KeyboardEventTap?
    private var statusMenuController: StatusMenuController?
    private let currentApplicationShortcut = CurrentApplicationShortcutController(
        store: UserDefaultsCurrentApplicationShortcutStore()
    )
    private lazy var cycler = WindowCycler(provider: windowProvider)
    private lazy var coordinator = SwitcherCoordinator(cycler: cycler)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController(
            currentApplicationShortcutController: currentApplicationShortcut,
            onCurrentApplicationShortcutChanged: { [weak self] isEnabled in
                self?.keyboardEventTap?.setCurrentApplicationShortcutEnabled(isEnabled)
            }
        )
        let keyboardPermissionState = PermissionManager.requestKeyboardCapturePermissions()
        PermissionManager.requestScreenRecordingPermissionIfNeeded()

        guard keyboardPermissionState.canCaptureKeyboard else {
            PermissionManager.showKeyboardCaptureHelp(permissionState: keyboardPermissionState)
            return
        }

        let eventTap = KeyboardEventTap(
            onCycleAllApplications: { [weak self] direction in
                self?.cycleAllApplications(direction: direction)
            },
            onCycleCurrentApplication: { [weak self] direction in
                self?.cycleCurrentApplication(direction: direction)
            },
            onModifierRelease: { [weak self] in
                self?.commitSelection()
            },
            onCancel: { [weak self] in
                self?.cancelSelection()
            }
        )
        eventTap.setCurrentApplicationShortcutEnabled(currentApplicationShortcut.isEnabled)

        keyboardEventTap = eventTap
        if !eventTap.start() {
            PermissionManager.showKeyboardCaptureHelp(
                permissionState: PermissionManager.keyboardCapturePermissionState
            )
        }
    }

    private func cycleAllApplications(direction: WindowCycleDirection) {
        let session = coordinator.press(scope: .allApplications, direction: direction)
        show(session: session)
    }

    private func cycleCurrentApplication(direction: WindowCycleDirection) {
        guard let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            overlayController.hide()
            return
        }

        let session = coordinator.press(
            scope: .currentApplication(processIdentifier: frontmostProcessIdentifier),
            direction: direction
        )
        show(session: session)
    }

    private func show(session: WindowCycleSession) {
        guard !session.windows.isEmpty else {
            overlayController.hide()
            keyboardEventTap?.setSessionActive(false)
            return
        }

        overlayController.show(
            session: session,
            onHoverWindow: { [weak self] windowID in
                self?.select(windowID: windowID)
            },
            onClickWindow: { [weak self] windowID in
                self?.select(windowID: windowID)
                self?.commitSelection()
            }
        )
        keyboardEventTap?.setSessionActive(true)
    }

    private func select(windowID: UInt32) {
        guard let session = coordinator.select(windowID: windowID) else {
            return
        }

        overlayController.update(session: session)
    }

    private func commitSelection() {
        keyboardEventTap?.setSessionActive(false)
        let selectedWindow = coordinator.release()
        overlayController.hide()

        guard let selectedWindow else {
            return
        }

        windowActivator.activate(selectedWindow)
    }

    private func cancelSelection() {
        keyboardEventTap?.setSessionActive(false)
        coordinator.cancel()
        overlayController.hide()
    }
}
