import Testing

@testable import OptaCore

@Suite("Frontmost application correction")
struct FrontmostApplicationCorrectionTests {
    @Test("promotes the frontmost application's window when CGWindowList ranks it behind another")
    func promotesFrontmostApplicationWindow() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 101
        )

        #expect(corrected.map(\.id) == [2, 1])
        #expect(corrected.map(\.recencyRank) == [0, 1])
    }

    @Test("leaves the order unchanged when the frontmost application is already ranked first")
    func leavesOrderUnchangedWhenAlreadyCorrect() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 100
        )

        #expect(corrected.map(\.id) == [1, 2])
        #expect(corrected.map(\.recencyRank) == [0, 1])
    }

    @Test("leaves the order unchanged when there is no known frontmost application")
    func leavesOrderUnchangedWhenFrontmostIsNil() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: nil
        )

        #expect(corrected.map(\.id) == [1, 2])
    }

    @Test("leaves the order unchanged when the frontmost application owns no window in the list")
    func leavesOrderUnchangedWhenFrontmostHasNoWindow() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 999
        )

        #expect(corrected.map(\.id) == [1, 2])
    }

    @Test("preserves the relative order of every other window when promoting the frontmost one")
    func preservesRelativeOrderOfOtherWindows() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 2, processIdentifier: 101, title: "Slack", recencyRank: 1),
            window(id: 3, processIdentifier: 102, title: "Chrome", recencyRank: 2),
            window(id: 4, processIdentifier: 103, title: "Xcode", recencyRank: 3),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 102
        )

        #expect(corrected.map(\.id) == [3, 1, 2, 4])
        #expect(corrected.map(\.recencyRank) == [0, 1, 2, 3])
    }
    @Test("promotes the frontmost application's real window past its menu bar item")
    func promotesRealWindowPastNonCyclableWindow() {
        // On macOS 14 and 15 an app's menu bar item is a layer-25 window that
        // the list orders ahead of every normal window.
        let windows = [
            window(id: 9, processIdentifier: 101, title: "", recencyRank: 0, layer: 25),
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 1),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 2),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 101
        )

        #expect(corrected.map(\.id) == [2, 9, 1])
        #expect(corrected.map(\.recencyRank) == [0, 1, 2])
    }

    @Test("skips an untitled overlay strip in front of the frontmost application's window")
    func skipsUntitledOverlayStrip() {
        let windows = [
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 0),
            window(id: 8, processIdentifier: 101, title: "", recencyRank: 1, hasAccessibilityWindow: false),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 2),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 101
        )

        #expect(corrected.map(\.id) == [2, 1, 8])
    }

    @Test("leaves the order unchanged when only a non-cyclable window sits ahead of the frontmost one")
    func leavesOrderWhenFrontmostIsFirstCyclableWindow() {
        let windows = [
            window(id: 9, processIdentifier: 100, title: "", recencyRank: 0, layer: 25),
            window(id: 2, processIdentifier: 101, title: "Chrome", recencyRank: 1),
            window(id: 1, processIdentifier: 100, title: "Ghostty", recencyRank: 2),
        ]

        let corrected = FrontmostApplicationCorrection.correcting(
            windows,
            frontmostProcessIdentifier: 101
        )

        #expect(corrected == windows)
    }
}

private func window(
    id: UInt32,
    processIdentifier: Int32,
    title: String,
    recencyRank: Int,
    layer: Int = 0,
    hasAccessibilityWindow: Bool = true
) -> WindowSnapshot {
    WindowSnapshot(
        id: id,
        processIdentifier: processIdentifier,
        applicationName: "App",
        title: title,
        isOnscreen: true,
        layer: layer,
        bounds: WindowBounds(x: 0, y: 0, width: 800, height: 600),
        recencyRank: recencyRank,
        hasAccessibilityWindow: hasAccessibilityWindow
    )
}
