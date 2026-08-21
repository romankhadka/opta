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
    private let keyboardCaptureStartupPolicy = KeyboardCaptureStartupPolicy()
    private var keyboardCapturePollTimer: Timer?
    private var keyboardCaptureHelpWasShown = false
    private var isEvaluatingKeyboardCapture = false
    private var focusTrackerIsRunning = false
    private let currentApplicationShortcut = CurrentApplicationShortcutController(
        store: UserDefaultsCurrentApplicationShortcutStore()
    )
    private lazy var cycler = WindowCycler(provider: windowProvider, recencyHistory: recencyHistory)
    private lazy var coordinator = SwitcherCoordinator(cycler: cycler)
    private lazy var focusTracker = WindowFocusTracker { [weak self] windowID in
        self?.recencyHistory.record(windowID: windowID)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusMenuController = StatusMenuController(
            currentApplicationShortcutController: currentApplicationShortcut,
            onCurrentApplicationShortcutChanged: { [weak self] isEnabled in
                self?.keyboardEventTap?.setCurrentApplicationShortcutEnabled(isEnabled)
            }
        )
        _ = PermissionManager.requestKeyboardCapturePermissions()
        PermissionManager.requestScreenRecordingPermissionIfNeeded()

        evaluateKeyboardCapture()
        startKeyboardCapturePolling()
    }

    // macOS grants and revokes keyboard capture whenever the user edits Privacy
    // & Security, and `tccutil reset` can revoke it under a running Opta. A
    // single check during launch left the menu bar icon in place with a
    // shortcut that silently did nothing until the user relaunched, so the
    // permission state is polled and the tap follows it.
    private func startKeyboardCapturePolling() {
        let timer = Timer(
            timeInterval: KeyboardCaptureStartupPolicy.pollInterval,
            repeats: true
        ) { _ in
            Task { @MainActor [weak self] in
                self?.evaluateKeyboardCapture()
            }
        }

        // Common modes keep the poll alive while a menu is tracking or the
        // permission alert is up.
        RunLoop.main.add(timer, forMode: .common)
        keyboardCapturePollTimer = timer
    }

    private func evaluateKeyboardCapture() {
        // The help alert runs modally and pumps the run loop, so the poll can
        // fire again while it is up.
        guard !isEvaluatingKeyboardCapture else {
            return
        }

        isEvaluatingKeyboardCapture = true
        defer { isEvaluatingKeyboardCapture = false }

        let permissionState = PermissionManager.keyboardCapturePermissionState
        let step = keyboardCaptureStartupPolicy.step(
            permissionState: permissionState,
            tapIsRunning: keyboardEventTap?.isRunning ?? false,
            helpWasShown: keyboardCaptureHelpWasShown
        )

        switch step {
        case .startTap:
            startKeyboardCapture()
        case .stopTap:
            stopKeyboardCapture()
        case .showHelpAndWait:
            showKeyboardCaptureHelp(permissionState: permissionState)
        case .wait, .idle:
            break
        }
    }

    private func startKeyboardCapture() {
        if !focusTrackerIsRunning {
            focusTracker.start()
            focusTrackerIsRunning = true
        }

        let eventTap = keyboardEventTap ?? makeKeyboardEventTap()
        keyboardEventTap = eventTap
        eventTap.setCurrentApplicationShortcutEnabled(currentApplicationShortcut.isEnabled)

        guard eventTap.start() else {
            // macOS reports the permission as granted yet refuses the tap. Say
            // so once; the poll keeps trying so a settings change recovers.
            logger.error("keyboard event tap refused despite granted permissions")
            showKeyboardCaptureHelp(permissionState: PermissionManager.keyboardCapturePermissionState)
            return
        }

        // Arm the help again so a later revocation is reported.
        keyboardCaptureHelpWasShown = false
        logger.info("keyboard event tap running")
    }

    private func stopKeyboardCapture() {
        logger.error("keyboard capture permission was revoked; tearing the tap down")
        keyboardEventTap?.stop()
    }

    private func showKeyboardCaptureHelp(permissionState: KeyboardCapturePermissionState) {
        guard !keyboardCaptureHelpWasShown else {
            return
        }

        keyboardCaptureHelpWasShown = true
        PermissionManager.showKeyboardCaptureHelp(permissionState: permissionState)
    }

    private func makeKeyboardEventTap() -> KeyboardEventTap {
        KeyboardEventTap(
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
    }

    private func cycleAllApplications(direction: WindowCycleDirection) {
        let measurement = PerformanceMetrics.begin("CycleAllApplications")
        defer { PerformanceMetrics.end(measurement) }

        let session = coordinator.press(scope: .allApplications, direction: direction)
        logger.debug(
            "cycle all direction=\(String(describing: direction), privacy: .public) windows=\(session.windows.map(\.id).description, privacy: .public) selected=\(session.selectedWindow?.id ?? 0, privacy: .public)"
        )
        show(session: session)
    }

    private func cycleCurrentApplication(direction: WindowCycleDirection) {
        let measurement = PerformanceMetrics.begin("CycleCurrentApplication")
        defer { PerformanceMetrics.end(measurement) }

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
        let measurement = PerformanceMetrics.begin("CycleActiveSession")
        defer { PerformanceMetrics.end(measurement) }

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
