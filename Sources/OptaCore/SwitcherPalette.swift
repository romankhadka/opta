/// Which ink color the switcher overlay draws its marks in.
///
/// Named for the ink it produces rather than for the appearance that uses it.
/// The dark palette draws with white ink and the light palette with black, so
/// cases named after appearances would read inverted at every call site.
public enum SwitcherInkTone: Equatable, Sendable {
    case white
    case black
}

/// The appearance-dependent half of the switcher overlay's visual tokens.
///
/// Everything here changes between Light and Dark appearance. Geometry --
/// corner radii, tile dimensions, font sizes, the shadow's radius and offset --
/// stays with the view, because it does not change.
public struct SwitcherPalette: Equatable, Sendable {
    public struct GradientStop: Equatable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
    }

    public struct Gradient: Equatable, Sendable {
        public let start: GradientStop
        public let end: GradientStop
    }

    // Ink-tinted: drawn in `ink` at the given opacity.
    public let ink: SwitcherInkTone
    public let containerEdgeOpacity: Double
    public let selectedFillOpacity: Double
    public let selectedEdgeOpacity: Double
    public let titleOpacity: Double
    public let applicationNameOpacity: Double
    public let missingIconOpacity: Double

    // Always black in both appearances; only the weight changes. Both are
    // recesses rather than marks -- a shadow is black in every macOS
    // appearance, and the backdrop is the well a preview sits in -- so
    // inverting them to white in Light appearance would turn a recess into a
    // glow.
    public let containerShadowOpacity: Double
    public let previewBackdropOpacity: Double

    /// Fills the preview well when a window has an application icon but no
    /// capture yet.
    public let iconPlaceholderGradient: Gradient

    /// Fills the preview well when a window has neither a capture nor an icon.
    public let previewPlaceholderGradient: Gradient

    /// The palette matching the appearance the overlay is being drawn in.
    public static func palette(forDarkAppearance isDarkAppearance: Bool) -> SwitcherPalette {
        isDarkAppearance ? .dark : .light
    }

    /// The values Quiet Glass shipped with. Changing anything here changes how
    /// the overlay looks in Dark appearance.
    public static let dark = SwitcherPalette(
        ink: .white,
        containerEdgeOpacity: 0.12,
        selectedFillOpacity: 0.10,
        selectedEdgeOpacity: 0.30,
        titleOpacity: 0.96,
        applicationNameOpacity: 0.50,
        missingIconOpacity: 0.18,
        containerShadowOpacity: 0.28,
        previewBackdropOpacity: 0.28,
        iconPlaceholderGradient: Gradient(
            start: GradientStop(red: 0.09, green: 0.10, blue: 0.11),
            end: GradientStop(red: 0.18, green: 0.20, blue: 0.20)
        ),
        previewPlaceholderGradient: Gradient(
            start: GradientStop(red: 0.10, green: 0.12, blue: 0.12),
            end: GradientStop(red: 0.20, green: 0.22, blue: 0.20)
        )
    )

    /// Quiet Glass in black ink. Black carries more weight than white at the
    /// same opacity, so the marks sit lower than their dark counterparts, and
    /// the shadow drops further still: the weight that grounds the panel
    /// against a dark desktop reads as grime against a bright one.
    public static let light = SwitcherPalette(
        ink: .black,
        containerEdgeOpacity: 0.10,
        selectedFillOpacity: 0.08,
        selectedEdgeOpacity: 0.22,
        titleOpacity: 0.88,
        applicationNameOpacity: 0.55,
        missingIconOpacity: 0.14,
        containerShadowOpacity: 0.18,
        previewBackdropOpacity: 0.10,
        iconPlaceholderGradient: Gradient(
            start: GradientStop(red: 0.95, green: 0.95, blue: 0.96),
            end: GradientStop(red: 0.86, green: 0.87, blue: 0.87)
        ),
        previewPlaceholderGradient: Gradient(
            start: GradientStop(red: 0.94, green: 0.95, blue: 0.95),
            end: GradientStop(red: 0.85, green: 0.86, blue: 0.85)
        )
    )
}
