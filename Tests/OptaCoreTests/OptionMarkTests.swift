import Foundation
import Testing

@testable import OptaCore

@Suite("Option mark")
struct OptionMarkTests {
    @Test("centres the application weight on the icon canvas")
    func centresApplicationWeightOnIconCanvas() {
        let bounds = OptionMark.bounds(strokeWidth: OptionMark.applicationStrokeWidth)

        #expect(bounds.x == 220)
        #expect(bounds.y == 308)
        #expect(bounds.width == 584)
        #expect(bounds.height == 408)
        #expect(bounds.x + bounds.width / 2 == OptionMark.canvas / 2)
        #expect(bounds.y + bounds.height / 2 == OptionMark.canvas / 2)
    }

    @Test("keeps the menu bar weight lighter than the application weight")
    func keepsMenuBarWeightLighterThanApplicationWeight() {
        // The menu bar draws the mark near 18 points wide. At the icon's weight
        // the branch and the through line close up at that size.
        #expect(OptionMark.menuBarStrokeWidth < OptionMark.applicationStrokeWidth)
    }

    @Test("draws the same shape the icon document ships")
    func drawsSameShapeIconDocumentShips() throws {
        let svg = try String(
            contentsOfFile: "Resources/Opta.icon/Assets/OptionMark.svg",
            encoding: .utf8
        )

        #expect(svg.contains(OptionMark.pathData(OptionMark.throughLine)))
        #expect(svg.contains(OptionMark.pathData(OptionMark.branch)))
        #expect(svg.contains("stroke-width=\"\(Int(OptionMark.applicationStrokeWidth))\""))
    }
}
