import Testing

@testable import OptaCore

@Suite("Focus follows close policy")
struct FocusFollowsClosePolicyTests {
    @Test("handles a close in the frontmost application")
    func handlesCloseInFrontmostApplication() {
        #expect(
            FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: 100,
                frontmostProcessIdentifier: 100,
                applicationName: "TextEdit"
            )
        )
    }

    @Test("ignores a close in a background application")
    func ignoresCloseInBackgroundApplication() {
        #expect(
            !FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: 100,
                frontmostProcessIdentifier: 101,
                applicationName: "TextEdit"
            )
        )
        #expect(
            !FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: 100,
                frontmostProcessIdentifier: nil,
                applicationName: "TextEdit"
            )
        )
    }

    @Test("ignores launchers and panels that close as they hand focus on", arguments: ["Hammerspoon", "Spotlight", "Alfred"])
    func ignoresLaunchers(applicationName: String) {
        #expect(
            !FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: 100,
                frontmostProcessIdentifier: 100,
                applicationName: applicationName
            )
        )
    }

    @Test("handles a close in an application without a name")
    func handlesCloseInUnnamedApplication() {
        #expect(
            FocusFollowsClosePolicy.shouldHandleClose(
                closedInProcessIdentifier: 100,
                frontmostProcessIdentifier: 100,
                applicationName: nil
            )
        )
    }
}
