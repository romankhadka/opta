import Foundation
import Testing

@Suite("Switcher overlay style")
struct SwitcherOverlayStyleTests {
    @Test("disables the rectangular native panel shadow")
    func disablesRectangularNativePanelShadow() throws {
        let source = try String(
            contentsOfFile: "Sources/Opta/SwitcherOverlayController.swift",
            encoding: .utf8
        )

        #expect(source.contains("panel.hasShadow = false"))
    }

    @Test("uses one corner radius without nested tile borders")
    func usesOneCornerRadiusWithoutNestedTileBorders() throws {
        let source = try String(
            contentsOfFile: "Sources/Opta/SwitcherOverlayController.swift",
            encoding: .utf8
        )

        #expect(source.contains("static let cornerRadius: CGFloat"))
        #expect(!source.contains("cornerRadius: 22"))
        #expect(!source.contains("cornerRadius: 11"))
        #expect(!source.contains("cornerRadius: 7"))
        #expect(!source.contains("lineWidth: isSelected ? 2 : 1"))
        #expect(!source.contains(".scaleEffect(isSelected"))
        #expect(!source.contains(": Color.white.opacity(0.07)"))
    }
}
