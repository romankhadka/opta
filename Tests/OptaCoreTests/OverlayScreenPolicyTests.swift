import CoreGraphics
import Testing

@testable import OptaCore

// Displays in AppKit coordinates. The 1440x900 primary display has a
// 1920x1080 display to its right, bottom edges aligned, and a 1440x900
// display stacked above it.
private let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
private let above = CGRect(x: 0, y: 900, width: 1440, height: 900)

@Suite("Overlay screen policy")
struct OverlayScreenPolicyTests {
    @Test("picks the display that holds most of the window", arguments: [
        // On the primary display.
        (WindowBounds(x: 100, y: 100, width: 800, height: 600), 0),
        // On the right display.
        (WindowBounds(x: 1600, y: -100, width: 800, height: 600), 1),
        // Across both, mostly on the right display.
        (WindowBounds(x: 1340, y: 100, width: 800, height: 600), 1),
        // Across both, mostly on the primary display.
        (WindowBounds(x: 1000, y: 100, width: 800, height: 600), 0),
        // On no display.
        (WindowBounds(x: -5000, y: -5000, width: 800, height: 600), nil),
    ] as [(WindowBounds, Int?)])
    func picksDisplayThatHoldsMostOfWindow(window: WindowBounds, expectedIndex: Int?) {
        let index = OverlayScreenPolicy.screenIndex(containing: window, screenFrames: [primary, right])

        #expect(index == expectedIndex)
    }

    @Test("flips the y axis between window-server and AppKit coordinates")
    func flipsYAxisBetweenCoordinateSpaces() {
        // A display above the primary one sits at positive AppKit y but at
        // negative window-server y.
        let window = WindowBounds(x: 100, y: -800, width: 800, height: 600)

        let index = OverlayScreenPolicy.screenIndex(containing: window, screenFrames: [primary, above])

        #expect(index == 1)
    }
}
