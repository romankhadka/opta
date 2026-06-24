import Testing

@testable import OptaCore

@Suite("Window activation matching")
struct WindowActivationMatcherTests {
    @Test("matches a candidate by window number first")
    func matchesCandidateByWindowNumberFirst() {
        let selectedWindow = window(id: 42, title: "Editor")
        let candidates = [
            WindowActivationCandidate(windowNumber: nil, title: "Editor", bounds: selectedWindow.bounds),
            WindowActivationCandidate(windowNumber: 42, title: "Other", bounds: nil),
        ]

        let match = WindowActivationMatcher.bestMatch(for: selectedWindow, candidates: candidates)

        #expect(match == candidates[1])
    }

    @Test("matches a candidate by title and bounds when window number is unavailable")
    func matchesCandidateByTitleAndBoundsWithoutWindowNumber() {
        let selectedWindow = window(
            id: 42,
            title: "Target",
            x: 150,
            y: 129,
            width: 2900,
            height: 1551
        )
        let candidates = [
            WindowActivationCandidate(
                windowNumber: nil,
                title: "Other",
                bounds: WindowBounds(x: 150, y: 129, width: 2900, height: 1551)
            ),
            WindowActivationCandidate(
                windowNumber: nil,
                title: "Target",
                bounds: WindowBounds(x: 150.5, y: 128.5, width: 2899.5, height: 1551.5)
            ),
        ]

        let match = WindowActivationMatcher.bestMatch(for: selectedWindow, candidates: candidates)

        #expect(match == candidates[1])
    }

    @Test("uses window order to break identical bounds ties")
    func usesWindowOrderToBreakIdenticalBoundsTies() {
        let selectedWindow = window(
            id: 42,
            title: "",
            x: 0,
            y: 30,
            width: 3200,
            height: 1770
        )
        let candidates = [
            WindowActivationCandidate(
                windowNumber: nil,
                title: "Current",
                bounds: selectedWindow.bounds,
                order: 0
            ),
            WindowActivationCandidate(
                windowNumber: nil,
                title: "Target",
                bounds: selectedWindow.bounds,
                order: 1
            ),
        ]

        let match = WindowActivationMatcher.bestMatch(
            for: selectedWindow,
            candidates: candidates,
            targetOrder: 1
        )

        #expect(match == candidates[1])
    }
}

private func window(
    id: UInt32,
    title: String,
    x: Double = 0,
    y: Double = 0,
    width: Double = 800,
    height: Double = 600
) -> WindowSnapshot {
    WindowSnapshot(
        id: id,
        processIdentifier: 100,
        applicationName: "App",
        title: title,
        isOnscreen: true,
        layer: 0,
        bounds: WindowBounds(x: x, y: y, width: width, height: height),
        recencyRank: 0
    )
}
