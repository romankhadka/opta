import CoreGraphics
import Testing

@testable import OptaCore

@Suite("Overlay screen policy")
struct OverlayScreenPolicyTests {
    // A 1440x900 primary display with a 1920x1080 display to its right,
    // bottom edges aligned, in AppKit coordinates.
    private let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    private let primaryHeight: CGFloat = 900

    @Test("picks the primary display for a window on it")
    func picksPrimaryDisplayForWindowOnIt() {
        let window = WindowBounds(x: 100, y: 100, width: 800, height: 600)

        let index = OverlayScreenPolicy.screenIndex(
            containing: window,
            screenFrames: [primary, external],
            primaryScreenHeight: primaryHeight
        )

        #expect(index == 0)
    }

    @Test("picks the external display for a window on it")
    func picksExternalDisplayForWindowOnIt() {
        let window = WindowBounds(x: 1600, y: -100, width: 800, height: 600)

        let index = OverlayScreenPolicy.screenIndex(
            containing: window,
            screenFrames: [primary, external],
            primaryScreenHeight: primaryHeight
        )

        #expect(index == 1)
    }

    @Test("picks the display that holds most of a window across two")
    func picksDisplayThatHoldsMostOfSpanningWindow() {
        let mostlyExternal = WindowBounds(x: 1340, y: 100, width: 800, height: 600)
        let mostlyPrimary = WindowBounds(x: 1000, y: 100, width: 800, height: 600)

        let externalIndex = OverlayScreenPolicy.screenIndex(
            containing: mostlyExternal,
            screenFrames: [primary, external],
            primaryScreenHeight: primaryHeight
        )
        let primaryIndex = OverlayScreenPolicy.screenIndex(
            containing: mostlyPrimary,
            screenFrames: [primary, external],
            primaryScreenHeight: primaryHeight
        )

        #expect(externalIndex == 1)
        #expect(primaryIndex == 0)
    }

    @Test("flips the y axis between window-server and AppKit coordinates")
    func flipsYAxisBetweenCoordinateSpaces() {
        // A display stacked above the primary one sits at positive AppKit y
        // but at negative window-server y.
        let above = CGRect(x: 0, y: 900, width: 1440, height: 900)
        let window = WindowBounds(x: 100, y: -800, width: 800, height: 600)

        let index = OverlayScreenPolicy.screenIndex(
            containing: window,
            screenFrames: [primary, above],
            primaryScreenHeight: primaryHeight
        )

        #expect(index == 1)
    }

    @Test("returns nil for a window off every display")
    func returnsNilForWindowOffEveryDisplay() {
        let window = WindowBounds(x: -5000, y: -5000, width: 800, height: 600)

        let index = OverlayScreenPolicy.screenIndex(
            containing: window,
            screenFrames: [primary, external],
            primaryScreenHeight: primaryHeight
        )

        #expect(index == nil)
    }
}
