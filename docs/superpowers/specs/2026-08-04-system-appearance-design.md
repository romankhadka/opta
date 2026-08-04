# System Appearance Support

## Problem

The switcher overlay is pinned to dark. It forces
`.environment(\.colorScheme, .dark)` on its root, draws every edge, label, and
selection highlight with `Color.white` literals, and falls back to dark-gray
gradients when a window preview or icon is missing. On a Mac set to Light
appearance the overlay reads as a foreign dark slab, and the tuned Quiet Glass
material resolves against the wrong side of the system's own vibrancy.

Opta should look like it belongs on the machine it runs on, in Light and Dark
alike, including the Auto setting that switches by time of day.

## Scope

The switcher overlay is the only hand-styled surface in the app. The status
menu is a native `NSMenu` and the permission prompts are native alerts; both
already track the system appearance without code changes. Nothing outside
`SwitcherOverlayController.swift` draws its own colors.

Out of scope, deliberately:

* No appearance override in the status menu, and no stored preference. The
  overlay follows System Settings and nothing else.
* No accent tinting. Selection stays neutral in both appearances so it does not
  compete with the application icons it sits behind.
* No layout, motion, capture, or material changes. Every Quiet Glass structural
  decision survives untouched.

## Approach

Split the visual tokens by whether they depend on appearance.

Scheme-independent tokens -- corner radii, tile dimensions, font sizes, icon
size, selected scale, animation duration, edge line width -- stay in
`SwitcherVisualStyle` inside the view file, where they are today.

Scheme-dependent tokens -- every opacity and every color -- move into a new
`SwitcherPalette` value type in `OptaCore`, with a `.dark` case that reproduces
today's shipped values exactly and a `.light` case tuned for a light material.

The alternative was inline `colorScheme == .dark ? … : …` ternaries at each of
the dozen or so call sites. That spreads the light tuning across the view body
where it cannot be read as a set or tested as a unit, and makes it easy to
convert nine call sites and forget the tenth.

## Components

### `Sources/OptaCore/SwitcherPalette.swift` (new)

`OptaCore` has no dependencies -- not SwiftUI, not AppKit -- and should not
gain one for this. So the palette cannot hold a `Color`. It carries an ink
*tone* plus scalars, and the view maps tone to a concrete color.

```swift
public enum SwitcherInkTone: Sendable {
    case light   // draw with white ink -- for dark appearance
    case dark    // draw with black ink -- for light appearance
}

public struct SwitcherPalette: Equatable, Sendable {
    public struct GradientStop: Equatable, Sendable {
        public let red, green, blue: Double
    }

    public struct Gradient: Equatable, Sendable {
        public let start, end: GradientStop
    }

    public let ink: SwitcherInkTone
    public let containerEdgeOpacity: Double
    public let containerShadowOpacity: Double
    public let selectedFillOpacity: Double
    public let selectedEdgeOpacity: Double
    public let titleOpacity: Double
    public let applicationNameOpacity: Double
    public let previewBackdropOpacity: Double
    public let missingIconOpacity: Double
    public let iconPlaceholderGradient: Gradient
    public let previewPlaceholderGradient: Gradient

    public static let dark: SwitcherPalette
    public static let light: SwitcherPalette

    public static func palette(forDarkAppearance isDark: Bool) -> SwitcherPalette
}
```

`.dark` holds the current constants verbatim, including the two placeholder
gradients' exact RGB triples, so the shipped dark look does not drift by a
single value.

`.light` mirrors it with dark ink: a soft black fill and a black hairline for
the selected tile, a lighter container shadow, and light-gray placeholder
gradients. Selection lands near 8% fill and 22% edge -- black ink needs less
opacity than white to carry the same weight. The shadow is the one value that
cannot simply be mirrored: a 28% black shadow that grounds the panel against a
dark desktop reads as grime against a bright one, so light appearance drops to
roughly 18%. These three numbers are starting points to confirm against the
real overlay during manual verification, not fixed requirements.

### `Sources/Opta/SwitcherOverlayController.swift`

* Remove `.environment(\.colorScheme, .dark)` from the overlay root.
* `SwitcherOverlayView` reads `@Environment(\.colorScheme)`, derives its
  palette through `SwitcherPalette.palette(forDarkAppearance:)`, and passes it
  down to each `SwitcherTileView`.
* A small private extension maps `SwitcherInkTone` to `Color.white` /
  `Color.black`, keeping SwiftUI knowledge in the view layer.
* Every `Color.white.opacity(…)` becomes `palette.inkColor.opacity(…)`. The
  preview backdrop, currently `Color.black.opacity(0.28)`, becomes palette
  driven, as do both placeholder gradients and the missing-icon square.
* The shadow color stays black in both appearances -- shadows are black
  everywhere -- but takes its opacity from the palette.
* `SwitcherVisualStyle` sheds the tokens that moved and keeps the rest.

### `NSPanel` configuration

No change. Leaving `panel.appearance` nil lets the panel inherit
`NSApp.effectiveAppearance`, so System Settings -> Appearance, including Auto,
reaches SwiftUI's `colorScheme`. SwiftUI re-renders the hosting view when the
effective appearance changes, so a live toggle is picked up without the
overlay being dismissed and reshown.

## Data flow

```
System Settings -> Appearance
  -> NSApp.effectiveAppearance
    -> NSPanel (inherits; appearance left nil)
      -> NSHostingView
        -> SwiftUI @Environment(\.colorScheme)
          -> SwitcherPalette.palette(forDarkAppearance:)
            -> SwitcherOverlayView  (container edge, shadow)
            -> SwitcherTileView     (fill, edge, labels, placeholders)
```

## Error handling

There is no failure mode to handle. `colorScheme` is always either `.light` or
`.dark`, and `palette(forDarkAppearance:)` is total over that domain. If a
future macOS adds a third scheme, the mapping falls back to `.dark`, which is
the current behavior.

## Testing

### `Tests/OptaCoreTests/SwitcherPaletteTests.swift` (new)

* `.dark` still carries the Quiet Glass values. This is a regression lock: the
  point of the change is that dark appearance looks identical afterward.
* `.light` differs from `.dark` on every token that carries color weight: ink
  tone, both placeholder gradients, the container shadow, the preview backdrop,
  and the selected fill and edge. A palette that is only half converted -- some
  values mirrored, others left at their dark value by accident -- fails here
  rather than shipping. Label opacities are exempt: they may legitimately land
  on the same number in both appearances, and the test should not force an
  artificial delta to satisfy itself.
* Every opacity lies in `0...1`.
* `palette(forDarkAppearance:)` returns the matching palette for both inputs.

### `Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift` (updated)

The existing suite reads the overlay source as text. Three changes:

* Replace the `.environment(\.colorScheme, .dark)` assertion with one that the
  view reads `@Environment(\.colorScheme)`.
* Assert no bare `Color.white` or `Color.black.opacity` literal survives in the
  view body, so a future edit cannot quietly reintroduce a pinned color.
* Move the assertions for tokens that migrated to the palette so they check
  `SwitcherPalette` instead of `SwitcherVisualStyle`.

Every layout, material-hierarchy, shadow-count, corner-radius, and
Reduce-Motion assertion stays exactly as written.

### Manual verification

* Show the switcher in Light appearance over a bright window and over a dark
  window; repeat in Dark appearance. Container edge, selected tile, and both
  label tiers must stay legible in all four.
* Toggle System Settings -> Appearance while Opta is running and confirm the
  next invocation matches, then toggle while the overlay is visible and
  confirm it restyles live.
* Force-quit a preview source so the icon and gradient fallbacks render, and
  check both in Light appearance.

## Success criteria

* In Light appearance the overlay reads as a light panel with dark ink,
  legible over both bright and dark windows behind it.
* In Dark appearance the overlay is pixel-identical to the current build.
* The overlay follows System Settings including Auto, with no preference of
  its own.
* `swift test` passes, including the new palette suite.
