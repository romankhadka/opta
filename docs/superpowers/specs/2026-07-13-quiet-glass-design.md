# Quiet Glass Switcher Design

Status: Approved

Date: 2026-07-13

## Context

Opta's window switcher is fast and functional, but its visual hierarchy is
heavier than the content it presents. The bright selected outline, broad
shadow, similar title and application-name emphasis, and highly transparent
outer material make the interface feel less deliberate over varied desktop
backgrounds.

The existing performance work establishes a strong baseline: warm overlay
rendering measures 0.274 ms median and 2.236 ms p95, while repeat-session
preview and icon lookups are effectively free. The redesign must preserve
those gains.

## Goals

* Make the switcher feel native, refined, and visually quiet.
* Improve the outer surface, selected-window state, and content hierarchy as
  one coherent system.
* Preserve the current footprint, preview resolution, and interaction model.
* Keep warm overlay rendering below 1 ms median and 4 ms p95.
* Respect Reduce Motion without weakening selection clarity.

## Non-goals

* Do not change window discovery, ordering, activation, or keyboard behavior.
* Do not change panel dimensions, grid sizing, preview dimensions, or capture
  scale.
* Do not introduce accent-color theming, per-application colors, or settings.
* Do not add headers, controls, badges, or other persistent interface chrome.
* Do not add per-tile materials, image filters, animated shadows, or additional
  ScreenCaptureKit work.

## Visual direction

The selected direction is Quiet Glass: one graphite glass surface, a soft
neutral selection plane, and crisp content hierarchy. Window previews remain
the dominant visual element. The surrounding interface supports scanning
without competing for attention.

### Outer surface

* Keep exactly one material-backed rounded rectangle.
* Set the overlay root's color scheme to dark so its single material resolves
  to a consistent graphite tone without stacking a second material or tint
  blur.
* Keep the one-pixel inner edge, reducing white opacity from 0.16 to 0.12.
* Reduce the shadow from 0.38 opacity, 32-point radius, and 18-point vertical
  offset to 0.28 opacity, 20-point radius, and 10-point offset.
* Preserve the borderless, transparent native panel with its native shadow
  disabled.

### Shape language

The container, tiles, previews, and content hit regions continue to use the
same 16-point continuous corner radius. This preserves one clear silhouette
and prevents the nested, mismatched-border appearance fixed previously.

### Selected window

* Reduce the selected fill from 20% white to 10% white.
* Replace the two-pixel, 55% white outline with a one-pixel, 30% white inner
  edge.
* Add a 1.012 compositor scale to the selected tile.
* Keep unselected windows at full opacity so users can scan alternatives.
* Do not add glow, animated blur, or a second shadow.

The fill and inner edge provide a complete static selection state. Scale is a
motion enhancement, not the only indicator.

### Content hierarchy

Keep the 160 by 148-point tile and 138 by 86-point preview unchanged.

* Window title: 12.5-point system semibold, near-opaque white.
* Application name: 10.5-point system regular, 50% white.
* Application icon: reduce from 22 to 20 points and align it with the two-line
  text block.
* Preserve one-line truncation for both labels.
* Preserve the current eight-point preview-to-metadata spacing, seven-point
  icon-to-text spacing, and ten-point tile padding.

### Motion

Selection changes use a 110 ms snappy transition. Only opacity and scale may
animate. Material, shadow radius, frame size, grid geometry, and imagery remain
static.

When Reduce Motion is enabled, the selected scale remains 1.0 and the fill and
inner edge update without a spatial transition.

## Component boundaries

### SwitcherVisualStyle

Add a private static style namespace beside `SwitcherLayout` for visual tokens
such as edge opacities, shadow values, font sizes, icon size, selection scale,
and transition duration. It contains constants only and owns no state.

### SwitcherOverlayView

This component continues to own the single outer material, inner edge, and
shadow. It does not gain new state or dependencies.

### SwitcherTileView

This component applies selected fill, selected inner edge, typography, icon
size, and compositor scale. It reads the existing `isSelected` value plus the
SwiftUI Reduce Motion environment value.

### Preview pipeline

`WindowPreviewProvider`, capture configuration, cache retention, and display
item construction remain unchanged.

## Data flow

The data path remains:

1. `WindowCycleSession` supplies ordered windows and the selected window ID.
2. `SwitcherOverlayController` combines each window with its cached preview
   and application icon.
3. `SwitcherOverlayView` lays out the existing stable grid.
4. `SwitcherTileView` derives presentation only from its display item,
   selection state, and Reduce Motion preference.

No observable model, timer, geometry reader, preference key, or asynchronous
work is added.

## Fallback and edge states

* Missing previews continue to show the existing application-icon gradient.
* Missing icons continue to show the existing neutral rounded placeholder.
* Fallbacks inherit the same selected fill and edge as captured previews.
* One-window, six-window, and multi-row layouts retain the current sizing and
  centering behavior.
* Long titles and application names remain single-line and truncated.
* Bright and dark underlying windows must both retain sufficient outer-edge,
  title, subtitle, and selection contrast.

## Performance guardrails

The implementation must retain the current rendering architecture:

* One outer material.
* One outer shadow.
* One selected static fill and one selected static inner edge.
* No per-tile material or shadow.
* No image processing or additional screenshot work.
* No layout-affecting animation.
* No change to cache lifetimes or capture resolution.

Use the existing `OverlayRender`, `PreviewRefresh`, and `IconLookup` signposts
to compare the release build against the established baseline. Reject or
simplify any visual change that raises warm `OverlayRender` above 1 ms median
or 4 ms p95 across at least ten repeated-session renders.

## Testing and verification

### Automated tests

Extend the switcher style regression tests before changing production code.
The tests must verify:

* The native panel shadow remains disabled.
* All structural rounded rectangles use the shared corner radius.
* The selected edge is one pixel rather than two.
* There is no per-tile material or selected-tile shadow.
* Reduce Motion disables the selected scale cue.
* Preview dimensions and capture limits remain unchanged.

Run the complete Swift test suite after implementation.

### Visual smoke matrix

Verify the signed release build with:

* Bright and dark windows behind the overlay.
* One, two, six, and at least seven switchable windows.
* Captured previews, missing previews, and missing icons.
* Keyboard forward and reverse selection.
* Pointer hover and click selection.
* Reduce Motion enabled and disabled.

### Performance comparison

Record the same repeated Option-Tab sequence used for the existing baseline.
Compare signpost distributions rather than a single run. Confirm:

* Warm `OverlayRender` stays below 1 ms median and 4 ms p95.
* `PreviewRefresh` and `IconLookup` behavior is unchanged.
* No new sustained CPU activity appears after the overlay closes.

### Release verification

* Build the release application from the task worktree.
* Verify the code signature and designated requirement.
* Install the exact build into `/Applications/Opta.app`.
* Confirm the installed executable matches the built executable.
* Complete a live Option-Tab smoke test and confirm Opta remains running.

## Acceptance criteria

The design is complete when:

* The switcher reads as one graphite glass surface with one consistent radius.
* The selected window is immediately clear without a heavy outline.
* Titles are primary and application names are visibly secondary.
* Reduce Motion preserves a clear static selected state.
* All interaction and fallback states behave as before.
* Automated, visual, performance, build, signing, installation, and smoke
  checks meet the requirements above.
