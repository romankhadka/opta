# Movement-Gated Hover Selection Design

Status: Approved

Date: 2026-07-15

## Context

The switcher supports selecting a window with the mouse: hovering a tile moves
the selection, clicking commits it. SwiftUI's `.onHover` reports an "entered"
event as soon as the overlay panel materializes underneath the pointer, even
when the pointer has not moved. When the user opens the switcher with
Option-Tab and the cursor happens to rest where a tile appears, that phantom
hover immediately steals the selection from the keyboard, which surprises
users who never touched the mouse.

Native macOS Command-Tab and third-party switchers such as AltTab solve this
the same way: pointer position is ignored until the pointer actually moves.

## Goals

* Hover selection engages only after the user physically moves the mouse
  during a switcher session.
* Once engaged, hover behaves exactly as before, including on the tile the
  cursor happened to start inside.
* Clicking a tile keeps working at all times; a click is always deliberate.
* Keyboard cycling is never disturbed by a stationary pointer.

## Non-goals

* Do not change window discovery, ordering, activation, or keyboard behavior.
* Do not add timing-based heuristics (delay windows); gating is purely by
  pointer movement.
* Do not add settings.

## Approaches considered

1. **Movement gate (selected).** Record the global pointer location when a
   session starts. Ignore hover callbacks until the pointer has moved beyond
   a small arming distance from that point; afterwards the gate stays open
   for the rest of the session. Deterministic, matches AltTab's proven
   behavior, immune to render-timing quirks.
2. Suppression window after show. Rejected: a fixed delay both blocks
   fast intentional mouse use and still mis-selects when the overlay renders
   slowly.
3. Swallow the first hover event only. Rejected: preview refreshes re-render
   the grid and can emit several phantom events, and it leaves the
   start-tile unable to re-arm without exiting and re-entering.

## Design

### HoverSelectionGate (OptaCore)

A small pure value type so the arming rule is unit-testable without AppKit:

* `init(initialPointerLocation: CGPoint, armingDistance: CGFloat = 4)`
* `mutating func shouldSelect(at location: CGPoint) -> Bool` — returns false
  while unarmed and within `armingDistance` of the initial location; arms and
  returns true once the pointer has moved at least `armingDistance` points
  (Euclidean distance); always true afterwards, even if the pointer returns
  to the initial location.

The 4 pt default absorbs sensor jitter from a touched-but-unmoved mouse while
remaining imperceptible to a real hand movement.

### SwitcherOverlayController

* When `show(session:onHoverWindow:onClickWindow:)` begins a new session
  (`currentSession == nil`, i.e. the panel was hidden), seed a fresh gate
  with `NSEvent.mouseLocation`.
* Route tile hover through a private handler that (a) asks the gate whether
  hover selection is armed, passing the current `NSEvent.mouseLocation`, and
  (b) drops the callback when the hovered window is already selected, so
  continuous hover events do not trigger redundant re-renders.
* Clicks bypass the gate.

### SwitcherTileView

Replace `.onHover` with `.onContinuousHover`, forwarding `.active` phases to
the hover callback. Plain `.onHover` fires only on entry, so after the
phantom entry event is suppressed, the tile the cursor started inside would
never become selectable until the cursor exited and re-entered. Continuous
hover reports every pointer movement inside the tile, so the first real
movement arms the gate and selects the tile the cursor is resting on.

## Testing

* Unit tests for `HoverSelectionGate`: stationary pointer never arms;
  sub-threshold jitter never arms; movement at/beyond threshold arms; gate
  stays armed after returning to the origin; distance is measured
  euclidean-diagonally, not per-axis.
* Existing suite must stay green; manual verification of the switcher
  covers the AppKit/SwiftUI layer, which has no test seam.
