import Testing

@testable import OptaCore

@Suite("Switcher palette")
struct SwitcherPaletteTests {
    @Test("locks the shipped Quiet Glass values to the dark palette")
    func locksShippedQuietGlassValuesToDarkPalette() {
        let palette = SwitcherPalette.dark

        #expect(palette.ink == .white)
        #expect(palette.containerEdgeOpacity == 0.12)
        #expect(palette.containerShadowOpacity == 0.28)
        #expect(palette.selectedFillOpacity == 0.10)
        #expect(palette.selectedEdgeOpacity == 0.30)
        #expect(palette.titleOpacity == 0.96)
        #expect(palette.applicationNameOpacity == 0.50)
        #expect(palette.previewBackdropOpacity == 0.28)
        #expect(palette.missingIconOpacity == 0.18)
        #expect(
            palette.iconPlaceholderGradient == SwitcherPalette.Gradient(
                start: SwitcherPalette.GradientStop(red: 0.09, green: 0.10, blue: 0.11),
                end: SwitcherPalette.GradientStop(red: 0.18, green: 0.20, blue: 0.20)
            )
        )
        #expect(
            palette.previewPlaceholderGradient == SwitcherPalette.Gradient(
                start: SwitcherPalette.GradientStop(red: 0.10, green: 0.12, blue: 0.12),
                end: SwitcherPalette.GradientStop(red: 0.20, green: 0.22, blue: 0.20)
            )
        )
    }

    @Test("draws the two appearances in opposite ink")
    func drawsTheTwoAppearancesInOppositeInk() {
        #expect(SwitcherPalette.dark.ink == .white)
        #expect(SwitcherPalette.light.ink == .black)
    }

    /// A half-converted palette -- some values mirrored for light appearance,
    /// others left at their dark value by accident -- fails here rather than
    /// shipping. Label opacities are deliberately not checked: they may
    /// legitimately land on the same number in both appearances.
    @Test("retunes every token that carries color weight")
    func retunesEveryTokenThatCarriesColorWeight() {
        let dark = SwitcherPalette.dark
        let light = SwitcherPalette.light

        #expect(light.ink != dark.ink)
        #expect(light.containerEdgeOpacity != dark.containerEdgeOpacity)
        #expect(light.containerShadowOpacity != dark.containerShadowOpacity)
        #expect(light.selectedFillOpacity != dark.selectedFillOpacity)
        #expect(light.selectedEdgeOpacity != dark.selectedEdgeOpacity)
        #expect(light.previewBackdropOpacity != dark.previewBackdropOpacity)
        #expect(light.iconPlaceholderGradient != dark.iconPlaceholderGradient)
        #expect(light.previewPlaceholderGradient != dark.previewPlaceholderGradient)
    }

    @Test("keeps every opacity and color component in range", arguments: [
        SwitcherPalette.dark,
        SwitcherPalette.light,
    ])
    func keepsEveryOpacityAndColorComponentInRange(palette: SwitcherPalette) {
        for opacity in palette.opacities {
            #expect((0...1).contains(opacity))
        }

        for component in palette.gradientComponents {
            #expect((0...1).contains(component))
        }
    }

    @Test("selects the palette matching the appearance")
    func selectsThePaletteMatchingTheAppearance() {
        #expect(SwitcherPalette.palette(forDarkAppearance: true) == .dark)
        #expect(SwitcherPalette.palette(forDarkAppearance: false) == .light)
    }

    @Test("grounds the panel more heavily in dark appearance than in light")
    func groundsThePanelMoreHeavilyInDarkAppearanceThanInLight() {
        #expect(SwitcherPalette.light.containerShadowOpacity < SwitcherPalette.dark.containerShadowOpacity)
    }
}

private extension SwitcherPalette {
    var opacities: [Double] {
        [
            containerEdgeOpacity,
            selectedFillOpacity,
            selectedEdgeOpacity,
            titleOpacity,
            applicationNameOpacity,
            missingIconOpacity,
            containerShadowOpacity,
            previewBackdropOpacity,
        ]
    }

    var gradientComponents: [Double] {
        [iconPlaceholderGradient, previewPlaceholderGradient]
            .flatMap { [$0.start, $0.end] }
            .flatMap { [$0.red, $0.green, $0.blue] }
    }
}
