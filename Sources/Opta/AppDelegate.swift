import AppKit
import OptaCore
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger.opta(category: "switcher")
    private let windowProvider = SystemWindowProvider()
    private let windowActivator = WindowActivator()
    private let overlayController = SwitcherOverlayController()
    private let recencyHistory = WindowRecencyHistory()
    private var keyboardEventTap: KeyboardEventTap?
    private var statusMenuController: StatusMenuController?
    private let currentApplicationShortcut = CurrentApplicationShortcutController(
        store: UserDefaultsCurrentApplicationShortcutStore()
    )
    private lazy var cycler = WindowCycler(provider: windowProvider, recencyHistory: recencyHistory)
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
            onCycleActiveSession: { [weak self] direction in
                self?.cycleActiveSession(direction: direction)
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
        logger.debug(
            "cycle all direction=\(String(describing: direction), privacy: .public) windows=\(session.windows.map(\.id).description, privacy: .public) selected=\(session.selectedWindow?.id ?? 0, privacy: .public)"
        )
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
        logger.debug(
            "cycle current pid=\(frontmostProcessIdentifier, privacy: .public) direction=\(String(describing: direction), privacy: .public) windows=\(session.windows.map(\.id).description, privacy: .public) selected=\(session.selectedWindow?.id ?? 0, privacy: .public)"
        )
        show(session: session)
    }

    private func cycleActiveSession(direction: WindowCycleDirection) {
        guard let session = coordinator.advanceActiveSession(direction) else {
            return
        }

        logger.debug(
            "cycle active direction=\(String(describing: direction), privacy: .public) selected=\(session.selectedWindow?.id ?? 0, privacy: .public)"
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

        if windowActivator.activate(selectedWindow) {
            logger.debug(
                "record selected window=\(selectedWindow.id, privacy: .public) app=\(selectedWindow.applicationName, privacy: .public) title=\(selectedWindow.displayTitle, privacy: .public)"
            )
            recencyHistory.record(windowID: selectedWindow.id)
        }
    }

    private func cancelSelection() {
        keyboardEventTap?.setSessionActive(false)
        coordinator.cancel()
        overlayController.hide()
    }
}
