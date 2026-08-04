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
size, selected scale, animation duration, edge line width, and the container
shadow's radius and Y offset -- stay in `SwitcherVisualStyle` inside the view
file, where they are today. The shadow's geometry is listed explicitly because
it sits next to the shadow's opacity, which does move; only the opacity is
appearance-dependent.

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
    case white
    case black
}

public struct SwitcherPalette: Equatable, Sendable {
    public struct GradientStop: Equatable, Sendable {
        public let red, green, blue: Double
    }

    public struct Gradient: Equatable, Sendable {
        public let start, end: GradientStop
    }

    // Ink-tinted: drawn in `ink` at the given opacity.
    public let ink: SwitcherInkTone
    public let containerEdgeOpacity: Double
    public let selectedFillOpacity: Double
    public let selectedEdgeOpacity: Double
    public let titleOpacity: Double
    public let applicationNameOpacity: Double
    public let missingIconOpacity: Double

    // Always black in both appearances; only the weight changes.
    public let containerShadowOpacity: Double
    public let previewBackdropOpacity: Double

    // Explicit sRGB triples.
    public let iconPlaceholderGradient: Gradient
    public let previewPlaceholderGradient: Gradient

    public static let dark: SwitcherPalette
    public static let light: SwitcherPalette

    public static func palette(forDarkAppearance isDark: Bool) -> SwitcherPalette
}
```

`SwitcherInkTone` is named for the ink it produces, not for the appearance that
uses it -- the dark palette draws with white ink and vice versa, so naming the
cases after appearances would invert on every read.

The container shadow and the preview backdrop are deliberately not ink-tinted.
Both are recesses rather than marks: a shadow is black in every macOS
appearance, and the backdrop is the well a preview sits in. Inverting either to
white in light appearance would turn a recess into a glow. Only their opacity
varies.

`.dark` holds the current constants verbatim, including the two placeholder
gradients' exact RGB triples, so the shipped dark look does not drift by a
single value.

`.light` mirrors it with black ink: a soft black fill and a black hairline for
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
* Every `Color.white.opacity(…)` becomes `palette.inkColor.opacity(…)`. Both
  placeholder gradients are rebuilt from the palette's `GradientStop` triples.
* The container shadow and the preview backdrop keep their literal
  `Color.black` and take only their opacity from the palette. Along with the
  `Color.clear` used for an unselected tile's fill, these are the only color
  literals that survive the change.
* `SwitcherVisualStyle` sheds the tokens that moved and keeps the rest.

### `NSPanel` configuration

No change. Leaving `panel.appearance` nil lets the panel inherit
`NSApp.effectiveAppearance`, so System Settings -> Appearance, including Auto,
reaches SwiftUI's `colorScheme`.

The guarantee this buys is that every invocation renders against the current
appearance: `render(session:)` runs on each `show`, and the palette is derived
from the environment at render time. Restyling *while the overlay is already
on screen* likely works too, since SwiftUI tracks effective-appearance changes,
but the spec does not claim it -- the overlay is only visible while a modifier
is held, so the appearance cannot be changed underneath it in practice, and an
unverifiable claim is worth less than the one above.

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

There is no failure mode to handle. `colorScheme` has exactly two cases, and
`palette(forDarkAppearance:)` is total over both.

## Testing

### `Tests/OptaCoreTests/SwitcherPaletteTests.swift` (new)

* `.dark` still carries the Quiet Glass values. This is a regression lock: the
  point of the change is that dark appearance looks identical afterward.
* `.light` differs from `.dark` on every token that carries color weight: ink
  tone, both placeholder gradients, the container edge, the container shadow,
  the preview backdrop, and the selected fill and edge. A palette that is only
  half converted -- some
  values mirrored, others left at their dark value by accident -- fails here
  rather than shipping. Label opacities are exempt: they may legitimately land
  on the same number in both appearances, and the test should not force an
  artificial delta to satisfy itself.
* Every opacity lies in `0...1`.
* `palette(forDarkAppearance:)` returns the matching palette for both inputs.

### `Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift` (updated)

The existing suite reads the overlay source as text. Exactly seven assertions
break, all inside `defines the Quiet Glass visual tokens`, because they assert
literals that are leaving `SwitcherOverlayController.swift`:

* `containerEdgeOpacity = 0.12`
* `containerShadowOpacity = 0.28`
* `selectedFillOpacity = 0.10`
* `selectedEdgeOpacity = 0.30`
* `titleOpacity = 0.96`
* `applicationNameOpacity = 0.50`
* `.environment(\.colorScheme, .dark)`

The first six move to `SwitcherPaletteTests`, asserted against `.dark` as
values rather than as source text. The seventh is replaced by an assertion that
the view reads `@Environment(\.colorScheme)`.

Add two assertions: that no `Color.white` literal survives anywhere in the
view, and that `.black.opacity(` appears exactly twice -- the container shadow
and the preview backdrop. Together these block a pinned color from creeping
back in without contradicting the two literals the design keeps on purpose.

Everything else stays exactly as written, including the shadow-radius,
shadow-offset, font-size, icon-size, scale, animation-duration, and edge
line-width assertions, the whole of `uses one shared structural corner radius`
and `guards selection motion with Reduce Motion`, and the material and
shadow-count checks in `uses a restrained material and shadow hierarchy`. The
name-presence checks in that last suite keep passing because the view will read
`palette.containerEdgeOpacity`, which still contains the asserted substring.

### Manual verification

* Show the switcher in Light appearance over a bright window and over a dark
  window; repeat in Dark appearance. Container edge, selected tile, and both
  label tiers must stay legible in all four.
* Toggle System Settings -> Appearance while Opta is running, without
  restarting it, and confirm the next invocation matches the new appearance.
  Repeat in the other direction.
* Force-quit a preview source so the icon and gradient fallbacks render, and
  check both in Light appearance.

## Success criteria

* In Light appearance the overlay reads as a light panel with dark ink,
  legible over both bright and dark windows behind it.
* In Dark appearance the overlay is visually unchanged. The `.dark` palette is
  locked to today's values by test, and the `colorScheme` override being
  removed was already redundant when the system was in Dark appearance.
* Every invocation renders against the appearance current at that moment, so
  the overlay follows System Settings including Auto, with no preference of
  its own.
* `swift test` passes, including the new palette suite.
