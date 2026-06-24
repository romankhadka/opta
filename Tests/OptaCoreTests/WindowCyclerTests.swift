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
}

private struct StubWindowProvider: WindowProviding {
    let windows: [WindowSnapshot]

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
    height: Double = 600
) -> WindowSnapshot {
    WindowSnapshot(
        id: id,
        processIdentifier: processIdentifier,
        applicationName: applicationName,
        title: title,
        isOnscreen: isOnscreen,
        layer: layer,
        bounds: WindowBounds(x: 0, y: 0, width: width, height: height)
    )
}
