import Testing

@testable import OptaCore

@Suite("Shift backward step gate")
struct ShiftBackwardStepGateTests {
    private enum Input {
        case shiftDown(sessionIsActive: Bool)
        case shiftUp
        case cycleKey(shiftIsDown: Bool)
        case optionUp
    }

    /// Feeds the inputs to a fresh gate. Each Shift input reports whether it
    /// stepped back; each cycle key reports whether it advanced. Releasing
    /// Option reports nothing.
    private func outcomes(_ inputs: [Input]) -> [Bool] {
        var gate = ShiftBackwardStepGate()
        var results: [Bool] = []

        for input in inputs {
            switch input {
            case .shiftDown(let sessionIsActive):
                results.append(gate.shiftChanged(isDown: true, sessionIsActive: sessionIsActive))
            case .shiftUp:
                results.append(gate.shiftChanged(isDown: false, sessionIsActive: true))
            case .cycleKey(let shiftIsDown):
                results.append(gate.cycleKeyPressed(shiftIsDown: shiftIsDown))
            case .optionUp:
                gate.reset()
            }
        }

        return results
    }

    @Test("Shift alone steps back once while the switcher is open")
    func shiftAloneStepsBack() {
        #expect(
            outcomes([.shiftDown(sessionIsActive: true), .shiftDown(sessionIsActive: true), .shiftUp])
                == [true, false, false]
        )
    }

    @Test("each Shift tap steps back once")
    func eachShiftTapStepsBack() {
        #expect(
            outcomes([.shiftDown(sessionIsActive: true), .shiftUp, .shiftDown(sessionIsActive: true)])
                == [true, false, true]
        )
    }

    @Test("Shift+Tab after Option+Tab steps back once, not twice")
    func shiftTabStepsBackOnce() {
        #expect(
            outcomes([.cycleKey(shiftIsDown: false), .shiftDown(sessionIsActive: true), .cycleKey(shiftIsDown: true)])
                == [true, true, false]
        )
    }

    @Test("later shifted cycle keys in the same Shift hold each step back")
    func laterShiftedCycleKeysStepBack() {
        #expect(
            outcomes([
                .shiftDown(sessionIsActive: true),
                .cycleKey(shiftIsDown: true),
                .cycleKey(shiftIsDown: true),
                .cycleKey(shiftIsDown: true),
            ]) == [true, false, true, true]
        )
    }

    @Test("Shift before the switcher opens leaves the opening key free")
    func shiftBeforeSessionDoesNotStepOrAbsorb() {
        #expect(
            outcomes([.shiftDown(sessionIsActive: false), .cycleKey(shiftIsDown: true)])
                == [false, true]
        )
    }

    @Test("releasing Shift clears the absorbed key")
    func shiftReleaseClearsAbsorb() {
        #expect(
            outcomes([.shiftDown(sessionIsActive: true), .shiftUp, .cycleKey(shiftIsDown: true)])
                == [true, false, true]
        )
    }

    @Test("releasing Option clears all Shift state")
    func optionReleaseClearsState() {
        #expect(
            outcomes([
                .shiftDown(sessionIsActive: true),
                .optionUp,
                .cycleKey(shiftIsDown: true),
                .shiftDown(sessionIsActive: true),
            ]) == [true, true, true]
        )
    }
}
