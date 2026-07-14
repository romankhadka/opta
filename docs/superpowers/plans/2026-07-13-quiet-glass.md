# Quiet Glass Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine Opta's switcher into the approved Quiet Glass design without changing its layout, capture pipeline, interaction behavior, or measured warm-render performance.

**Architecture:** Keep the existing controller, display-item, grid, and preview data flow intact. Add a private constant-only `SwitcherVisualStyle` namespace in the existing overlay source, then apply its tokens exclusively in `SwitcherOverlayView` and `SwitcherTileView`; Reduce Motion controls only the compositor scale and transition.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Swift Testing, ScreenCaptureKit, OSSignposter, xctrace, worktrunk

---

## File map

* Modify `Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift` to encode the
  approved visual tokens, shared-radius rule, Reduce Motion guard, effect-layer
  limit, and unchanged preview/capture dimensions.
* Modify `Sources/Opta/SwitcherOverlayController.swift` to add static visual
  tokens and apply Quiet Glass styling. Do not change controller state,
  `WindowPreviewProvider`, panel geometry, or `SwitcherLayout` values.
* Preserve
  `docs/superpowers/specs/2026-07-13-quiet-glass-design.md` as the authoritative
  design and validation contract.

### Task 1: Implement Quiet Glass with test-first visual guardrails

**Files:**

* Modify: `Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift`
* Modify: `Sources/Opta/SwitcherOverlayController.swift:174-338`

- [ ] **Step 1: Replace the existing style tests with the approved failing contract**

Replace `Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift` with:

```swift
import Foundation
import Testing

@Suite("Switcher overlay style")
struct SwitcherOverlayStyleTests {
    @Test("disables the rectangular native panel shadow")
    func disablesRectangularNativePanelShadow() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlay.contains("panel.hasShadow = false"))
    }

    @Test("uses one shared radius for structural surfaces")
    func usesOneSharedRadiusForStructuralSurfaces() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlay.contains("static let cornerRadius: CGFloat = 16"))
        #expect(!overlay.contains("cornerRadius: 22"))
        #expect(!overlay.contains("cornerRadius: 11"))
        #expect(!overlay.contains("cornerRadius: 7"))
        #expect(!overlay.contains("lineWidth: isSelected ? 2 : 1"))
        #expect(!overlay.contains(": Color.white.opacity(0.07)"))
    }

    @Test("defines the approved Quiet Glass visual tokens")
    func definesApprovedQuietGlassVisualTokens() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlay.contains("private enum SwitcherVisualStyle"))
        #expect(overlay.contains("static let containerEdgeOpacity = 0.12"))
        #expect(overlay.contains("static let containerShadowOpacity = 0.28"))
        #expect(overlay.contains("static let containerShadowRadius: CGFloat = 20"))
        #expect(overlay.contains("static let containerShadowYOffset: CGFloat = 10"))
        #expect(overlay.contains("static let selectedFillOpacity = 0.10"))
        #expect(overlay.contains("static let selectedEdgeOpacity = 0.30"))
        #expect(overlay.contains("static let selectedEdgeLineWidth: CGFloat = 1"))
        #expect(overlay.contains("static let selectedScale: CGFloat = 1.012"))
        #expect(overlay.contains("static let selectionAnimationDuration = 0.11"))
        #expect(overlay.contains("static let titleFontSize: CGFloat = 12.5"))
        #expect(overlay.contains("static let applicationFontSize: CGFloat = 10.5"))
        #expect(overlay.contains("static let applicationIconSize: CGFloat = 20"))
        #expect(overlay.contains(".environment(\\.colorScheme, .dark)"))
    }

    @Test("guards the selected scale with Reduce Motion")
    func guardsSelectedScaleWithReduceMotion() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlay.contains("@Environment(\\.accessibilityReduceMotion) private var reduceMotion"))
        #expect(overlay.contains(".scaleEffect(isSelected && !reduceMotion"))
        #expect(overlay.contains("reduceMotion ? nil : .snappy("))
        #expect(!overlay.contains(".scaleEffect(isSelected ?"))
    }

    @Test("keeps expensive effects at container scope")
    func keepsExpensiveEffectsAtContainerScope() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")

        #expect(overlay.components(separatedBy: ".fill(.ultraThinMaterial)").count == 2)
        #expect(overlay.components(separatedBy: ".shadow(").count == 2)
        #expect(!overlay.contains("lineWidth: 2"))
    }

    @Test("preserves tile preview and capture dimensions")
    func preservesTilePreviewAndCaptureDimensions() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")
        let previewProvider = try source(at: "Sources/Opta/WindowPreviewProvider.swift")

        #expect(overlay.contains("static let tileWidth: CGFloat = 160"))
        #expect(overlay.contains("static let tileHeight: CGFloat = 148"))
        #expect(overlay.contains(".frame(width: 138, height: 86)"))
        #expect(previewProvider.contains("previewFillPixelWidth: CGFloat = 276"))
        #expect(previewProvider.contains("previewFillPixelHeight: CGFloat = 172"))
        #expect(previewProvider.contains("maximumCaptureScale: CGFloat = 2"))
    }

    private func source(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
```

- [ ] **Step 2: Run the focused test and verify the new contract fails**

Run:

```bash
rtk swift test --filter SwitcherOverlayStyleTests
```

Expected: FAIL in the Quiet Glass token and Reduce Motion tests because
`SwitcherVisualStyle`, the guarded scale, and the new values do not exist.
The existing radius, panel-shadow, effect-count, and capture-size assertions
remain green.

- [ ] **Step 3: Add the constant-only visual style namespace**

Insert this directly after `SwitcherLayout` in
`Sources/Opta/SwitcherOverlayController.swift`:

```swift
private enum SwitcherVisualStyle {
    static let containerEdgeOpacity = 0.12
    static let containerShadowOpacity = 0.28
    static let containerShadowRadius: CGFloat = 20
    static let containerShadowYOffset: CGFloat = 10
    static let selectedFillOpacity = 0.10
    static let selectedEdgeOpacity = 0.30
    static let selectedEdgeLineWidth: CGFloat = 1
    static let selectedScale: CGFloat = 1.012
    static let selectionAnimationDuration = 0.11
    static let titleFontSize: CGFloat = 12.5
    static let titleOpacity = 0.96
    static let applicationFontSize: CGFloat = 10.5
    static let applicationNameOpacity = 0.50
    static let applicationIconSize: CGFloat = 20
}
```

Do not move geometry values out of `SwitcherLayout`; visual and layout tokens
remain separate responsibilities.

- [ ] **Step 4: Apply the outer Quiet Glass surface**

Replace the outer rounded-rectangle block in `SwitcherOverlayView.body` with:

```swift
RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.white.opacity(SwitcherVisualStyle.containerEdgeOpacity),
                lineWidth: 1
            )
    )
    .shadow(
        color: .black.opacity(SwitcherVisualStyle.containerShadowOpacity),
        radius: SwitcherVisualStyle.containerShadowRadius,
        y: SwitcherVisualStyle.containerShadowYOffset
    )
```

Then apply dark material resolution to the overlay root without another visual
layer:

```swift
.frame(maxWidth: .infinity, maxHeight: .infinity)
.environment(\.colorScheme, .dark)
```

- [ ] **Step 5: Apply hierarchy, selection, and Reduce Motion behavior**

Add the environment value at the top of `SwitcherTileView`:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
```

Replace the metadata icon and text styles with:

```swift
icon
    .frame(
        width: SwitcherVisualStyle.applicationIconSize,
        height: SwitcherVisualStyle.applicationIconSize
    )

VStack(alignment: .leading, spacing: 1) {
    Text(item.window.displayTitle)
        .font(
            .system(
                size: SwitcherVisualStyle.titleFontSize,
                weight: .semibold,
                design: .default
            )
        )
        .lineLimit(1)
        .foregroundStyle(Color.white.opacity(SwitcherVisualStyle.titleOpacity))

    Text(item.window.applicationName)
        .font(
            .system(
                size: SwitcherVisualStyle.applicationFontSize,
                weight: .regular,
                design: .default
            )
        )
        .lineLimit(1)
        .foregroundStyle(
            Color.white.opacity(SwitcherVisualStyle.applicationNameOpacity)
        )
}
```

Replace the selected background and edge with:

```swift
.background(
    RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
        .fill(
            isSelected
                ? Color.white.opacity(SwitcherVisualStyle.selectedFillOpacity)
                : Color.clear
        )
)
.overlay {
    if isSelected {
        RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
            .strokeBorder(
                Color.white.opacity(SwitcherVisualStyle.selectedEdgeOpacity),
                lineWidth: SwitcherVisualStyle.selectedEdgeLineWidth
            )
    }
}
.scaleEffect(isSelected && !reduceMotion ? SwitcherVisualStyle.selectedScale : 1)
```

Replace the current animation modifier with:

```swift
.animation(
    reduceMotion ? nil : .snappy(
        duration: SwitcherVisualStyle.selectionAnimationDuration
    ),
    value: isSelected
)
```

Do not change `VStack` spacing, `HStack` spacing, padding, frame dimensions,
preview code, fallback gradients, panel positioning, or capture code.

- [ ] **Step 6: Run the focused tests and resolve compile errors only**

Run:

```bash
rtk swift test --filter SwitcherOverlayStyleTests
```

Expected: 6 tests pass with zero issues. If Swift cannot infer the optional
animation type, change only the false branch to
`Animation.snappy(duration: SwitcherVisualStyle.selectionAnimationDuration)`
and update the source assertion to require `reduceMotion ? nil : Animation.snappy(`.

- [ ] **Step 7: Run the full suite and inspect the diff**

Run:

```bash
rtk swift test
rtk git diff --check
rtk git diff --stat
rtk git diff -- Sources/Opta/SwitcherOverlayController.swift Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift
```

Expected: 45 tests pass across 11 suites, `git diff --check` is silent, and no
file outside the two listed implementation files plus the approved docs has
changed.

- [ ] **Step 8: Commit the green implementation**

```bash
rtk git add Sources/Opta/SwitcherOverlayController.swift Tests/OptaCoreTests/SwitcherOverlayStyleTests.swift
rtk git commit -m 'Refine switcher with Quiet Glass styling' -m 'Quiet the container and selected state while improving text hierarchy.

Preserve the existing layout and capture pipeline, and respect Reduce
Motion without adding expensive visual effects.'
```

Expected: one implementation commit with no attribution trailer.

### Task 2: Measure the signed release build

**Files:** None

- [ ] **Step 1: Build and validate the task-worktree release app**

```bash
rtk ./scripts/build_app.sh
rtk codesign --verify --deep --strict --verbose=2 .build/release/Opta.app
```

Expected: production build succeeds; code signing reports that the app is
valid on disk and satisfies its designated requirement.

- [ ] **Step 2: Install the exact signed build and launch it**

```bash
rtk pkill -x opta || true
rtk sleep 1
rtk rm -rf /Applications/Opta.app
rtk ditto .build/release/Opta.app /Applications/Opta.app
rtk cmp .build/release/Opta.app/Contents/MacOS/opta /Applications/Opta.app/Contents/MacOS/opta
rtk codesign --verify --deep --strict --verbose=2 /Applications/Opta.app
rtk open -n /Applications/Opta.app
rtk sleep 2
rtk pgrep -x opta
```

Expected: `cmp` is silent, signature verification succeeds, and `pgrep`
returns one Opta PID.

- [ ] **Step 3: Warm the persistent UI objects before recording**

Run one complete session before xctrace starts so the warm-render threshold
does not include first-use SwiftUI hosting or application-icon work:

```bash
rtk osascript -e 'tell application "System Events"' -e 'key down option' -e 'key code 48' -e 'delay 0.25' -e 'key up option' -e 'end tell'
rtk sleep 0.1
```

Expected: the overlay appears and closes once; Opta remains running.

- [ ] **Step 4: Record at least ten repeated-session renders**

Use the Time Profiler template because it includes the existing points-of-
interest signposts:

```bash
rtk rm -rf /tmp/opta-quiet-glass.trace
PID="$(rtk pgrep -x opta)"
(
  rtk sleep 0.5
  rtk osascript -e 'tell application "System Events"' -e 'repeat 12 times' -e 'key down option' -e 'key code 48' -e 'delay 0.25' -e 'key up option' -e 'delay 0.55' -e 'end repeat' -e 'end tell'
) &
rtk xcrun xctrace record --template 'Time Profiler' --attach "$PID" --time-limit 12s --output /tmp/opta-quiet-glass.trace --no-prompt
```

Expected: xctrace saves `/tmp/opta-quiet-glass.trace`; Opta remains running.

- [ ] **Step 5: Export the signpost table**

```bash
rtk rm -f /tmp/opta-quiet-glass-signposts.xml
rtk xcrun xctrace export --input /tmp/opta-quiet-glass.trace --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost"]' --output /tmp/opta-quiet-glass-signposts.xml
```

Expected: export completes and the XML file contains `OverlayRender`,
`PreviewRefresh`, and `IconLookup` rows. Do not use `xctrace export --toc`.

- [ ] **Step 6: Parse interval distributions**

Run this parser exactly:

```bash
rtk ruby -r rexml/document -e '
  doc = REXML::Document.new(File.read(ARGV.fetch(0)))
  elements = {}
  doc.elements.each("//row/*") do |element|
    id = element.attributes["id"]
    elements[id] = element if id
  end
  value = lambda do |element|
    next nil unless element
    target = element.attributes["ref"] ? elements[element.attributes["ref"]] : element
    target&.text || target&.attributes&.fetch("fmt", nil)
  end
  begins = {}
  durations = Hash.new { |hash, key| hash[key] = [] }
  doc.elements.each("//row") do |row|
    fields = row.elements.to_a
    timestamp = value.call(fields[0])&.to_i
    event = value.call(fields[3])
    identifier = value.call(fields[5])
    name = value.call(fields[6])
    next unless timestamp && event && identifier && name
    key = [name, identifier]
    if event == "Begin"
      begins[key] = timestamp
    elsif event == "End" && begins[key]
      durations[name] << (timestamp - begins.delete(key)) / 1_000_000.0
    end
  end
  durations.sort.each do |name, values|
    sorted = values.sort
    median = sorted[sorted.length / 2]
    p95 = sorted[((sorted.length - 1) * 0.95).round]
    puts "%s n=%d min=%.3f median=%.3f p95=%.3f max=%.3f" % [name, sorted.length, sorted.first, median, p95, sorted.last]
  end
' /tmp/opta-quiet-glass-signposts.xml
```

Expected acceptance:

* `OverlayRender` has at least 10 completed intervals, median below 1.000 ms,
  and p95 below 4.000 ms.
* Recorded `PreviewRefresh` intervals remain cache hits near zero because the
  first capture completed during warm-up.
* Repeated `IconLookup` intervals remain cache hits near zero.

Report the tool (`xctrace Time Profiler`), the twelve-session Option-Tab sequence,
trace path, interval counts, median, p95, and pass/fail result in the final
implementation handoff. If either render threshold fails, stop: do not call
the design performance-safe and do not merge. Compare the trace to the
established 0.274 ms median and 2.236 ms p95 baseline before changing code.

- [ ] **Step 7: Confirm idle CPU returns to zero**

```bash
rtk sleep 3
PID="$(rtk pgrep -x opta)"
rtk ps -o pid=,pcpu=,rss=,etime= -p "$PID"
```

Expected: Opta is alive and reports 0.0% CPU when idle. Record RSS for
comparison, but do not impose a memory threshold because ScreenCaptureKit and
SwiftUI framework residency varies after first use.

### Task 3: Execute the visual and interaction smoke matrix

**Files:** None

- [ ] **Step 1: Exercise controlled one-, two-, six-, and seven-window layouts**

Record whether Option + grave accent is enabled in Opta's status menu. Enable
it for this matrix when necessary, and restore the recorded state in Step 4.

Create seven empty temporary files outside the repository:

```bash
rtk touch /tmp/opta-quiet-glass-1.txt /tmp/opta-quiet-glass-2.txt /tmp/opta-quiet-glass-3.txt /tmp/opta-quiet-glass-4.txt /tmp/opta-quiet-glass-5.txt /tmp/opta-quiet-glass-6.txt /tmp/opta-quiet-glass-7.txt
```

For each count (1, 2, 6, then 7), launch a fresh TextEdit instance with exactly
that many named files, bring it frontmost, and use Option + grave accent to
show the current-application switcher. Run this zsh loop:

```bash
for count in 1 2 6 7; do
  files=()
  for index in $(rtk seq 1 "$count"); do
    files+=("/tmp/opta-quiet-glass-${index}.txt")
  done
  rtk open -na TextEdit "${files[@]}"
  rtk sleep 1
  textedit_pid="$(rtk pgrep -n -x TextEdit)"
  (
    rtk sleep 0.5
    rtk screencapture -x "/tmp/opta-quiet-glass-${count}.png"
    rtk osascript -e 'tell application "System Events" to key up option'
  ) &
  rtk osascript -e 'tell application "System Events"' -e 'key down option' -e 'delay 0.1' -e 'key code 50' -e 'end tell'
  rtk sleep 1
  rtk kill "$textedit_pid"
  rtk sleep 1
done
```

Verify:

* One and two windows remain centered with unchanged panel geometry.
* Six windows use one row.
* Seven windows wrap to two rows without clipping the selected 1.012 scale.
* Every structural surface uses the same continuous radius.
* The title is primary, application name secondary, and selected edge quiet
  but immediately visible.

Capture each state to `/tmp/opta-quiet-glass-{count}.png`. Release Option after
each capture so Opta completes the session. Kill only the fresh TextEdit PID
between counts; do not close an existing TextEdit process.

- [ ] **Step 2: Verify bright, dark, keyboard, pointer, and fallback states**

Against the installed signed build:

1. Show Opta over a bright TextEdit window and a dark terminal window.
2. Cycle forward with Option-Tab and backward with Option-Shift-Tab.
3. Hover a non-selected tile and confirm the selection changes once.
4. Click a non-selected tile and confirm that exact window activates.
5. Capture the first cold overlay frame before previews finish and confirm the
   icon-gradient fallback inherits the same selection treatment.
6. Confirm the unchanged neutral icon placeholder remains present in source
   and is not given a material or shadow.

Expected: all states retain readable titles, secondary app names, one outer
surface, and one selected fill/edge without flicker or layout movement.

- [ ] **Step 3: Verify Reduce Motion and restore the user's setting**

Open System Settings → Accessibility → Display. Record the current Reduce
Motion setting, then:

1. Enable Reduce Motion.
2. Cycle forward and backward; confirm selection fill and edge update while
   tile scale remains 1.0.
3. Disable Reduce Motion temporarily; confirm the subtle scale transition is
   present without changing layout.
4. Restore the exact setting recorded before the test.

Expected: static selection remains clear in both modes, and the user's system
setting is unchanged after verification.

- [ ] **Step 4: Remove temporary visual-test artifacts**

```bash
rtk rm -f /tmp/opta-quiet-glass-1.txt /tmp/opta-quiet-glass-2.txt /tmp/opta-quiet-glass-3.txt /tmp/opta-quiet-glass-4.txt /tmp/opta-quiet-glass-5.txt /tmp/opta-quiet-glass-6.txt /tmp/opta-quiet-glass-7.txt
```

Expected: only screenshots and performance traces remain under `/tmp`; the
repository is unchanged by smoke-test setup. Restore the Option + grave accent
status-menu setting recorded in Step 1.

### Task 4: Final verification and handoff

**Files:** None

- [ ] **Step 1: Run fresh repository verification**

```bash
rtk swift test
rtk git diff --check
rtk git status --short
rtk git log --oneline -4
```

Expected: 45 tests pass across 11 suites, diff checking is silent, and the
worktree is clean.

- [ ] **Step 2: Rebuild and reinstall from the final commit**

```bash
rtk ./scripts/build_app.sh
rtk codesign --verify --deep --strict --verbose=2 .build/release/Opta.app
rtk pkill -x opta || true
rtk sleep 1
rtk rm -rf /Applications/Opta.app
rtk ditto .build/release/Opta.app /Applications/Opta.app
rtk cmp .build/release/Opta.app/Contents/MacOS/opta /Applications/Opta.app/Contents/MacOS/opta
rtk codesign --verify --deep --strict --verbose=2 /Applications/Opta.app
rtk open -n /Applications/Opta.app
rtk sleep 2
```

Expected: final release build, copy comparison, and both signature checks
succeed.

- [ ] **Step 3: Complete the final live smoke test**

```bash
rtk osascript -e 'tell application "System Events"' -e 'key down option' -e 'delay 0.1' -e 'key code 48' -e 'delay 0.25' -e 'key up option' -e 'end tell'
rtk sleep 3
rtk pgrep -x opta
PID="$(rtk pgrep -x opta)"
rtk ps -o pid=,pcpu=,rss=,etime= -p "$PID"
```

Expected: the selected window activates, Opta remains alive, and idle CPU
returns to 0.0%.

- [ ] **Step 4: Review requirements line by line before integration**

Confirm every goal, non-goal, visual token, component boundary, fallback,
performance guardrail, automated test, smoke state, signature check, and
acceptance criterion in
`docs/superpowers/specs/2026-07-13-quiet-glass-design.md` has matching evidence.
Do not merge or push while any item lacks evidence.
