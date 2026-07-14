import Foundation
import Testing

@Suite("Switcher overlay style")
struct SwitcherOverlayStyleTests {
    @Test("disables the rectangular native panel shadow")
    func disablesRectangularNativePanelShadow() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlaySource.contains("panel.hasShadow = false"))
    }

    @Test("uses one shared structural corner radius")
    func usesOneSharedStructuralCornerRadius() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlaySource.contains("static let cornerRadius: CGFloat = 16"))
        #expect(!overlaySource.contains("cornerRadius: 22"))
        #expect(!overlaySource.contains("cornerRadius: 11"))
        #expect(!overlaySource.contains("cornerRadius: 7"))
        #expect(!overlaySource.contains("lineWidth: isSelected ? 2 : 1"))
        #expect(!overlaySource.contains(": Color.white.opacity(0.07)"))
    }

    @Test("defines the Quiet Glass visual tokens")
    func definesQuietGlassVisualTokens() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlaySource.contains("private enum SwitcherVisualStyle"))
        #expect(overlaySource.contains("static let containerEdgeOpacity = 0.12"))
        #expect(overlaySource.contains("static let containerShadowOpacity = 0.28"))
        #expect(overlaySource.contains("static let containerShadowRadius: CGFloat = 20"))
        #expect(overlaySource.contains("static let containerShadowYOffset: CGFloat = 10"))
        #expect(overlaySource.contains("static let selectedFillOpacity = 0.10"))
        #expect(overlaySource.contains("static let selectedEdgeOpacity = 0.30"))
        #expect(overlaySource.contains("static let selectedEdgeLineWidth: CGFloat = 1"))
        #expect(overlaySource.contains("static let selectedScale: CGFloat = 1.012"))
        #expect(overlaySource.contains("static let selectionAnimationDuration = 0.11"))
        #expect(overlaySource.contains("static let titleFontSize: CGFloat = 12.5"))
        #expect(overlaySource.contains("static let titleOpacity = 0.96"))
        #expect(overlaySource.contains("static let applicationFontSize: CGFloat = 10.5"))
        #expect(overlaySource.contains("static let applicationNameOpacity = 0.50"))
        #expect(overlaySource.contains("static let applicationIconSize: CGFloat = 20"))
        #expect(overlaySource.contains(".environment(\\.colorScheme, .dark)"))
    }

    @Test("guards selection motion with Reduce Motion")
    func guardsSelectionMotionWithReduceMotion() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(
            overlaySource.contains(
                "@Environment(\\.accessibilityReduceMotion) private var reduceMotion"
            )
        )
        #expect(overlaySource.contains(".scaleEffect(isSelected && !reduceMotion"))
        #expect(overlaySource.contains("reduceMotion ? nil : .snappy("))
        #expect(!overlaySource.contains(".scaleEffect(isSelected ?"))
    }

    @Test("uses a restrained material and shadow hierarchy")
    func usesRestrainedMaterialAndShadowHierarchy() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")
        let overlayStart = try #require(
            overlaySource.range(of: "private struct SwitcherOverlayView")
        )
        let tileStart = try #require(
            overlaySource.range(of: "private struct SwitcherTileView")
        )
        let overlaySection = overlaySource[overlayStart.lowerBound..<tileStart.lowerBound]
        let tileSection = overlaySource[tileStart.lowerBound...]

        #expect(overlaySection.contains(".fill(.ultraThinMaterial)"))
        #expect(overlaySection.contains(".shadow("))
        #expect(!tileSection.contains(".fill(.ultraThinMaterial)"))
        #expect(!tileSection.contains(".shadow("))

        #expect(overlaySection.contains("containerEdgeOpacity"))
        #expect(overlaySection.contains("containerShadowOpacity"))
        #expect(overlaySection.contains("containerShadowRadius"))
        #expect(overlaySection.contains("containerShadowYOffset"))

        #expect(tileSection.contains("selectedFillOpacity"))
        #expect(tileSection.contains("selectedEdgeOpacity"))
        #expect(tileSection.contains("selectedEdgeLineWidth"))
        #expect(tileSection.contains("selectedScale"))
        #expect(tileSection.contains("selectionAnimationDuration"))
        #expect(tileSection.contains("titleFontSize"))
        #expect(tileSection.contains("titleOpacity"))
        #expect(tileSection.contains("applicationFontSize"))
        #expect(tileSection.contains("applicationNameOpacity"))
        #expect(tileSection.contains("applicationIconSize"))

        #expect(overlaySource.components(separatedBy: ".fill(.ultraThinMaterial)").count == 2)
        #expect(overlaySource.components(separatedBy: ".shadow(").count == 2)
        #expect(!overlaySource.contains("lineWidth: 2"))
    }

    @Test("preserves overlay layout and capture dimensions")
    func preservesOverlayLayoutAndCaptureDimensions() throws {
        let overlaySource = try source(at: "Sources/Opta/SwitcherOverlayController.swift")
        let previewSource = try source(at: "Sources/Opta/WindowPreviewProvider.swift")

        #expect(overlaySource.contains("static let tileWidth: CGFloat = 160"))
        #expect(overlaySource.contains("static let tileHeight: CGFloat = 148"))
        #expect(overlaySource.contains(".frame(width: 138, height: 86)"))
        #expect(previewSource.contains("private static let previewFillPixelWidth: CGFloat = 276"))
        #expect(previewSource.contains("private static let previewFillPixelHeight: CGFloat = 172"))
        #expect(previewSource.contains("private static let maximumCaptureScale: CGFloat = 2"))
    }

    private func source(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
