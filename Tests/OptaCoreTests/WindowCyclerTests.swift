import Testing

@testable import OptaCore

@Suite("Window cycling")
struct WindowCyclerTests {
    @Test("keeps only visible normal windows for all applications")
    func filtersVisibleNormalWindows() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Editor"),
                window(id: 2, processIdentifier: 100, title: "Hidden", isOnscreen: false),
                window(id: 3, processIdentifier: 101, title: "Menu", layer: 25),
                window(id: 4, processIdentifier: 102, title: "Browser"),
                window(id: 5, processIdentifier: 103, title: "Zero", width: 0, height: 500),
            ]
        )
        let cycler = WindowCycler(provider: provider)

        let session = cycler.start(scope: .allApplications)

        #expect(session.windows.map(\.id) == [1, 4])
        #expect(session.selectedWindow?.id == 1)
    }

    @Test("limits current application cycling to the frontmost process")
    func filtersCurrentApplicationWindows() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Mail"),
                window(id: 2, processIdentifier: 101, title: "Browser"),
                window(id: 3, processIdentifier: 101, title: "Downloads"),
            ]
        )
        let cycler = WindowCycler(provider: provider)

        let session = cycler.start(scope: .currentApplication(processIdentifier: 101))

        #expect(session.windows.map(\.id) == [2, 3])
        #expect(session.selectedWindow?.id == 2)
    }

    @Test("orders windows by most recent use")
    func ordersWindowsByMostRecentUse() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Older", recencyRank: 20),
                window(id: 2, processIdentifier: 101, title: "Current", recencyRank: 0),
                window(id: 3, processIdentifier: 102, title: "Previous", recencyRank: 10),
            ]
        )
        let cycler = WindowCycler(provider: provider)

        let session = cycler.start(scope: .allApplications)

        #expect(session.windows.map(\.id) == [2, 3, 1])
        #expect(session.selectedWindow?.id == 2)
    }

    @Test("explicitly used windows outrank stale system stacking order")
    func explicitlyUsedWindowsOutrankStaleSystemStackingOrder() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "System Front", recencyRank: 0),
                window(id: 2, processIdentifier: 101, title: "User Selected", recencyRank: 10),
                window(id: 3, processIdentifier: 102, title: "Older", recencyRank: 20),
            ]
        )
        let recencyHistory = WindowRecencyHistory()
        recencyHistory.record(windowID: 2)
        let cycler = WindowCycler(provider: provider, recencyHistory: recencyHistory)

        let session = cycler.start(scope: .allApplications)

        #expect(session.windows.map(\.id) == [2, 1, 3])
        #expect(session.selectedWindow?.id == 2)
    }

    @Test("new frontmost windows outrank older recorded windows")
    func newFrontmostWindowsOutrankOlderRecordedWindows() {
        let provider = MutableWindowProvider(
            windows: [
                window(id: 2, processIdentifier: 100, title: "Older Ghostty Window", recencyRank: 10),
                window(id: 3, processIdentifier: 101, title: "Older Browser Window", recencyRank: 20),
            ]
        )
        let recencyHistory = WindowRecencyHistory()
        recencyHistory.record(windowID: 2)
        recencyHistory.record(windowID: 3)
        let cycler = WindowCycler(provider: provider, recencyHistory: recencyHistory)

        _ = cycler.start(scope: .allApplications)
        provider.windows = [
            window(id: 1, processIdentifier: 100, title: "New Ghostty Window", recencyRank: 0),
            window(id: 2, processIdentifier: 100, title: "Older Ghostty Window", recencyRank: 10),
            window(id: 3, processIdentifier: 101, title: "Older Browser Window", recencyRank: 20),
        ]

        let session = cycler.start(scope: .allApplications)

        #expect(session.windows.map(\.id) == [1, 3, 2])
        #expect(session.selectedWindow?.id == 1)
    }

    @Test("a window focused outside the switcher stays ahead of stale recorded windows")
    func windowFocusedOutsideSwitcherStaysAheadOfStaleRecordedWindows() {
        // Earlier Opta usage recorded two windows: most recent id=10, then id=11.
        let recencyHistory = WindowRecencyHistory()
        recencyHistory.record(windowID: 11)
        recencyHistory.record(windowID: 10)

        let provider = MutableWindowProvider(
            windows: [
                window(id: 10, processIdentifier: 100, title: "A", recencyRank: 0),
                window(id: 11, processIdentifier: 101, title: "B", recencyRank: 1),
            ]
        )
        let cycler = WindowCycler(provider: provider, recencyHistory: recencyHistory)

        // Seed the observed-window set from a first session.
        _ = cycler.start(scope: .allApplications)

        // The user opens a brand-new window (id=1) outside Opta; it is frontmost.
        provider.windows = [
            window(id: 1, processIdentifier: 102, title: "N", recencyRank: 0),
            window(id: 10, processIdentifier: 100, title: "A", recencyRank: 1),
            window(id: 11, processIdentifier: 101, title: "B", recencyRank: 2),
        ]
        let afterOpeningNewWindow = cycler.start(scope: .allApplications)
        #expect(afterOpeningNewWindow.windows.first?.id == 1)

        // The user switches to window A (id=10) via Opta.
        recencyHistory.record(windowID: 10)
        provider.windows = [
            window(id: 10, processIdentifier: 100, title: "A", recencyRank: 0),
            window(id: 1, processIdentifier: 102, title: "N", recencyRank: 1),
            window(id: 11, processIdentifier: 101, title: "B", recencyRank: 2),
        ]
        let afterSwitchingAway = cycler.start(scope: .allApplications)

        // The newly opened window was the most recent before A, so it must remain
        // second instead of sinking below the stale recorded window B.
        #expect(afterSwitchingAway.windows.map(\.id) == [10, 1, 11])
    }

    @Test("an already-known window that regains focus outside the switcher is treated as current")
    func alreadyKnownWindowRegainingFocusOutsideSwitcherIsTreatedAsCurrent() {
        let provider = MutableWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
                window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
            ]
        )
        let recencyHistory = WindowRecencyHistory()
        let cycler = WindowCycler(provider: provider, recencyHistory: recencyHistory)

        // Seed the observed-window set from a first session, then the user
        // explicitly switches to Ghostty (id=1) via Opta.
        _ = cycler.start(scope: .allApplications)
        recencyHistory.record(windowID: 1)

        // The user clicks a link in Ghostty that activates the EXISTING Chrome
        // window (id=2) directly, outside Opta. Chrome is neither a brand-new
        // window nor something Opta recorded, but it is now genuinely frontmost.
        provider.windows = [
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 0),
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 1),
        ]
        let session = cycler.start(scope: .allApplications)

        // Chrome must be recognized as current, with Ghostty next in line --
        // not the reverse, which would offer Chrome as "next" while already there.
        #expect(session.windows.map(\.id) == [2, 1])
        #expect(session.selectedWindow?.id == 2)
    }

    @Test("excludes untitled windows without a matching accessibility window")
    func excludesUntitledWindowsWithoutAccessibilityWindow() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Messages"),
                window(id: 2, processIdentifier: 100, title: "", hasAccessibilityWindow: false),
                window(id: 3, processIdentifier: 100, title: "", hasAccessibilityWindow: false),
                window(id: 4, processIdentifier: 100, title: "", hasAccessibilityWindow: true),
            ]
        )
        let cycler = WindowCycler(provider: provider)

        let session = cycler.start(scope: .allApplications)

        #expect(session.windows.map(\.id) == [1, 4])
    }

    @Test("advancing a session wraps through available windows")
    func advancesAndWraps() {
        var session = WindowCycleSession(
            windows: [
                window(id: 1, processIdentifier: 100, title: "One"),
                window(id: 2, processIdentifier: 101, title: "Two"),
            ]
        )

        session.advance()
        #expect(session.selectedWindow?.id == 2)

        session.advance()
        #expect(session.selectedWindow?.id == 1)
    }

    @Test("reversing a session wraps backward through available windows")
    func reversesAndWraps() {
        var session = WindowCycleSession(
            windows: [
                window(id: 1, processIdentifier: 100, title: "One"),
                window(id: 2, processIdentifier: 101, title: "Two"),
                window(id: 3, processIdentifier: 102, title: "Three"),
            ]
        )

        session.advance(.backward)
        #expect(session.selectedWindow?.id == 3)

        session.advance(.backward)
        #expect(session.selectedWindow?.id == 2)
    }

    @Test("selecting a window by id changes the selected window")
    func selectsWindowByID() {
        var session = WindowCycleSession(
            windows: [
                window(id: 1, processIdentifier: 100, title: "One"),
                window(id: 2, processIdentifier: 101, title: "Two"),
                window(id: 3, processIdentifier: 102, title: "Three"),
            ]
        )

        let didSelectKnownWindow = session.select(windowID: 3)
        #expect(didSelectKnownWindow)
        #expect(session.selectedWindow?.id == 3)

        let didSelectUnknownWindow = session.select(windowID: 99)
        #expect(!didSelectUnknownWindow)
        #expect(session.selectedWindow?.id == 3)
    }

    @Test("the first hotkey press selects the next window")
    func firstHotkeyPressSelectsNextWindow() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Current"),
                window(id: 2, processIdentifier: 101, title: "Previous"),
                window(id: 3, processIdentifier: 102, title: "Older"),
            ]
        )
        let cycler = WindowCycler(provider: provider)
        let coordinator = SwitcherCoordinator(cycler: cycler)

        let firstPress = coordinator.press(scope: .allApplications)
        #expect(firstPress.selectedWindow?.id == 2)

        let secondPress = coordinator.press(scope: .allApplications)
        #expect(secondPress.selectedWindow?.id == 3)

        let selectedWindow = coordinator.release()
        #expect(selectedWindow?.id == 3)
        #expect(coordinator.activeSession == nil)
    }

    @Test("the first backward hotkey press selects the last window")
    func firstBackwardHotkeyPressSelectsLastWindow() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Current"),
                window(id: 2, processIdentifier: 101, title: "Previous"),
                window(id: 3, processIdentifier: 102, title: "Older"),
            ]
        )
        let cycler = WindowCycler(provider: provider)
        let coordinator = SwitcherCoordinator(cycler: cycler)

        let firstPress = coordinator.press(scope: .allApplications, direction: .backward)
        #expect(firstPress.selectedWindow?.id == 3)

        let secondPress = coordinator.press(scope: .allApplications, direction: .backward)
        #expect(secondPress.selectedWindow?.id == 2)
    }

    @Test("an active session can advance backward without another scope hotkey")
    func activeSessionCanAdvanceBackwardWithoutAnotherScopeHotkey() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Current"),
                window(id: 2, processIdentifier: 100, title: "Previous"),
                window(id: 3, processIdentifier: 101, title: "Other App"),
            ]
        )
        let cycler = WindowCycler(provider: provider)
        let coordinator = SwitcherCoordinator(cycler: cycler)

        let firstPress = coordinator.press(scope: .currentApplication(processIdentifier: 100))
        #expect(firstPress.selectedWindow?.id == 2)

        let shiftedPress = coordinator.advanceActiveSession(.backward)
        #expect(shiftedPress?.selectedWindow?.id == 1)
        #expect(coordinator.release()?.id == 1)
    }

    @Test("cancelling a session clears it without selecting a window")
    func cancellingClearsSessionWithoutSelecting() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Current"),
                window(id: 2, processIdentifier: 101, title: "Previous"),
            ]
        )
        let cycler = WindowCycler(provider: provider)
        let coordinator = SwitcherCoordinator(cycler: cycler)

        _ = coordinator.press(scope: .allApplications)
        coordinator.cancel()

        #expect(coordinator.activeSession == nil)
        #expect(coordinator.release() == nil)
    }

    @Test("selecting a window updates the active coordinator session")
    func selectingWindowUpdatesActiveCoordinatorSession() {
        let provider = StubWindowProvider(
            windows: [
                window(id: 1, processIdentifier: 100, title: "Current"),
                window(id: 2, processIdentifier: 101, title: "Previous"),
                window(id: 3, processIdentifier: 102, title: "Older"),
            ]
        )
        let cycler = WindowCycler(provider: provider)
        let coordinator = SwitcherCoordinator(cycler: cycler)

        _ = coordinator.press(scope: .allApplications)
        let selectedSession = coordinator.select(windowID: 3)

        #expect(selectedSession?.selectedWindow?.id == 3)
        #expect(coordinator.release()?.id == 3)
    }
}

private struct StubWindowProvider: WindowProviding {
    let windows: [WindowSnapshot]

    func availableWindows() -> [WindowSnapshot] {
        windows
    }
}

private final class MutableWindowProvider: WindowProviding {
    var windows: [WindowSnapshot]

    init(windows: [WindowSnapshot]) {
        self.windows = windows
    }

    func availableWindows() -> [WindowSnapshot] {
        windows
    }
}

private func window(
    id: UInt32,
    processIdentifier: Int32,
    applicationName: String = "App",
    title: String,
    isOnscreen: Bool = true,
    layer: Int = 0,
    width: Double = 800,
    height: Double = 600,
    recencyRank: Int = 0,
    hasAccessibilityWindow: Bool = true
) -> WindowSnapshot {
    WindowSnapshot(
        id: id,
        processIdentifier: processIdentifier,
        applicationName: applicationName,
        title: title,
        isOnscreen: isOnscreen,
        layer: layer,
        bounds: WindowBounds(x: 0, y: 0, width: width, height: height),
        recencyRank: recencyRank,
        hasAccessibilityWindow: hasAccessibilityWindow
    )
}
