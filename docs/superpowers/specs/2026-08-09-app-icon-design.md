# Opta App Icon Design

Status: Approved

Date: 2026-08-09

## Context

Opta shipped without an icon, so macOS drew it with the generic application
placeholder everywhere the app appears. Opta is an `LSUIElement` agent and has
no Dock tile, which changes where an icon has to work: Finder, Spotlight, Login
Items, the About panel, and the Accessibility, Input Monitoring, and Screen
Recording permission prompts. Those surfaces show the icon between 16 and 512
points, and the small end dominates.

macOS 26 also replaced the flat application icon with a layered document that
the system renders six ways: Default, Dark, Tinted Light, Tinted Dark, Clear
Light, and Clear Dark. Tinted and Clear discard the artwork's colour entirely,
so an icon that carries its meaning in colour loses that meaning in a third of
the appearances it will be seen in.

## Goals

* Give Opta a mark that is its own, not a generic window-management image.
* Stay legible at 16 points, the size that does the most work for an agent app.
* Render correctly in all six macOS 26 appearances from a single source.
* Keep working on macOS 14 and 15, which have no appearance-aware icon system.
* Fit the Quiet Glass language the switcher overlay already follows.

## Non-goals

* Do not add a Dock presence or otherwise change `LSUIElement`.
* Do not introduce a second mark for the menu bar; that item stays a template
  image, which is a different problem with different rules.
* Do not add per-appearance artwork variants. One document, six renditions.

## The mark

The icon is the Option key glyph, `⌥`.

Opta's entire premise is that key: hold Option, the panel appears, release
Option, the window activates. The glyph is also, by origin, a railway track
switch — a line that continues, and a branch that hands you somewhere else —
which is what Opta does to a window stack. No other switcher claims the symbol,
and Mac users who would install this app read it instantly.

It survives the appearance system because it is two strokes and nothing else.
Tinted and Clear strip colour and leave form, and form is all this mark was ever
carrying.

Two alternatives were drawn and rejected:

* **Stacked panes.** Two overlapping rounded rectangles. Honest about the
  subject, but it is the same image as every duplicate, copy, and Mission
  Control icon in the system. No identity.
* **Mark inside a pane.** The glyph on a translucent window pane. The pane's
  edges fought the squircle, and it dissolved into the background below 32
  points.

### Geometry

Drawn on the 1024-point canvas, not taken from a system font — the font glyph is
too wide and too short to fill a squircle.

* Stroke width 96, round caps and joins, matching the continuous corner radius
  the overlay uses.
* Through line: `M268 356 H462 L636 668 H756`.
* Branch: `M660 356 H756`.
* Stroke centres put the outer bounds at 220–804 horizontally and 308–716
  vertically, centring the mark on the canvas.

Stroke weight was chosen against the 16-point rendition. At 78 the mark loses
authority and at 112 it crowds the squircle.

## Colour

The background is a single `automatic-gradient` seeded at
`extended-srgb:0.10000,0.14000,0.26000` — a deep blue steel. The mark is white.

The seed is not a free choice, and this is the constraint most likely to trip up
a future change.

macOS derives the Dark rendition's mark colour from the background seed. Past a
threshold in lightness and saturation, the system stops drawing the mark white
and instead renders it as a material tinted toward the background, which drops
the mark to roughly 2.5:1 against its own field. The first blue steel tried,
`0.16,0.20,0.28`, fell on the wrong side of that line and produced a mark at
`rgb(82,92,113)` on near-black.

The threshold is not monotonic. `0.17,0.19,0.22` keeps the mark white and
`0.17,0.19,0.23` does not, yet `0.12,0.15,0.22` — a far bluer colour — keeps it.
Darker seeds tolerate much more chroma. The shipped seed sits inside a wide safe
region rather than next to the discontinuity: its neighbours at 0.09, 0.11, and
0.12 red all hold the white mark.

None of this is documented, and `fill-specializations` does not override it.
That key parses — an invalid `appearance` value is rejected, so the decoder does
read it — but neither a layer-level nor a background-level specialization for
`dark-color` changes what `ictool` renders, including a deliberately absurd one.
`fully-specialize-for` and `layer-color` are not schema keys at all; unknown keys
are dropped silently. Explicit `linear-gradient` fills, which take exactly two
colours, are recoloured the same way, so the behaviour belongs to the dark
appearance treatment rather than to `automatic-gradient`.

Putting the coloured field in an artwork layer instead of the top-level `fill`,
to hide the chroma from the heuristic, fails differently: a full-bleed layer
swallows the mark and takes over the Tinted and Clear renditions completely. The
background belongs in `fill`.

Because the boundary is a system heuristic rather than a contract,
`scripts/preview_icon.sh` samples the Dark rendition and fails if the mark is no
longer white.

## Build integration

`scripts/build_app.sh` compiles `Resources/Opta.icon` in two passes.

`actool` produces `Assets.car`, which carries the six renditions macOS 26 selects
between, and reports `CFBundleIconName` and `CFBundleIconFile` in a partial
plist that is merged into `Info.plist` with `PlistBuddy`. Merging rather than
hand-copying keeps the bundle keys from drifting from the document's name.

`actool` also emits an `.icns`, but only at 16, 32, 128, and 256 points, so
Finder's larger icon sizes would upscale it on the macOS 14 and 15 installs that
have no `Assets.car` to read. The build replaces it: `ictool` renders the
Default appearance at every size `iconutil` accepts, and `iconutil` assembles an
`.icns` that stays sharp to 1024.

Both tools ship inside Xcode, which the README already requires at version 26 or
newer. `ictool` lives in `Icon Composer.app/Contents/Executables`.

## Verification

* All six renditions render from the document and were reviewed on light and
  dark grounds.
* The Dark rendition's mark samples pure white, and the check fails as intended
  when the seed is moved back to `0.16,0.20,0.28`.
* The built bundle carries `Assets.car` and an `.icns` holding `ic04`, `ic05`,
  `ic07` through `ic14`, with `CFBundleIconName` set to `Opta`, and passes
  `codesign --verify --strict`.

`NSWorkspace.icon(forFile:)` drawn into an off-screen `NSImage` is not a valid
check. It returns grey-on-black for macOS 26 icons because the compositing the
system does is missing; Calculator renders the same way through that path.
