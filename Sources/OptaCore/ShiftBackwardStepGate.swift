/// Decides when Shift moves the switcher selection back.
///
/// Two promises meet here. Pressing Shift alone while the switcher is open
/// steps the selection back one window. Option+Tab followed by Shift+Tab also
/// steps back one window, not two. A Shift press that stepped back therefore
/// absorbs the first cycle key pressed during the same Shift hold; every later
/// cycle key in that hold steps back as usual.
///
/// A Shift press with no open switcher does not step, so Option+Shift+Tab
/// still opens the switcher one window backward.
public struct ShiftBackwardStepGate: Equatable, Sendable {
    private var shiftWasDown = false
    private var absorbsNextCycleKey = false

    public init() {}

    /// Records a Shift change while Option is held. Returns true when the
    /// selection must step back.
    public mutating func shiftChanged(isDown: Bool, sessionIsActive: Bool) -> Bool {
        defer { shiftWasDown = isDown }

        guard isDown else {
            absorbsNextCycleKey = false
            return false
        }

        guard !shiftWasDown, sessionIsActive else {
            return false
        }

        absorbsNextCycleKey = true
        return true
    }

    /// Records a Tab or grave press. Returns false when the press only
    /// completes a Shift+key chord whose Shift already stepped back.
    public mutating func cycleKeyPressed(shiftIsDown: Bool) -> Bool {
        guard shiftIsDown, absorbsNextCycleKey else {
            return true
        }

        absorbsNextCycleKey = false
        return false
    }

    /// Clears all state when Option is released.
    public mutating func reset() {
        self = ShiftBackwardStepGate()
    }
}
