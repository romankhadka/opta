import Foundation
import Testing

@Suite("Switcher hover selection")
struct SwitcherHoverSelectionTests {
    @Test("requires pointer movement before hover can change selection")
    func requiresPointerMovementBeforeHoverCanChangeSelection() throws {
        let overlaySource = try String(
            contentsOfFile: "Sources/Opta/SwitcherOverlayController.swift",
            encoding: .utf8
        )

        #expect(
            overlaySource.contains(
                "HoverSelectionGate(initialPointerLocation: NSEvent.mouseLocation)"
            )
        )
        #expect(
            overlaySource.contains(
                "hoverSelectionGate?.shouldSelect(at: NSEvent.mouseLocation) == true"
            )
        )
        #expect(overlaySource.contains(".onContinuousHover { phase in"))
        #expect(!overlaySource.contains(".onHover {"))
    }
}
