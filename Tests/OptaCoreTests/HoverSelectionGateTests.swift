import CoreGraphics
import Testing

@testable import OptaCore

@Suite("Hover selection gate")
struct HoverSelectionGateTests {
    @Test("stationary pointer never arms hover selection")
    func stationaryPointerNeverArmsHoverSelection() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let firstHoverShouldSelect = gate.shouldSelect(at: CGPoint(x: 100, y: 100))
        let secondHoverShouldSelect = gate.shouldSelect(at: CGPoint(x: 100, y: 100))

        #expect(!firstHoverShouldSelect)
        #expect(!secondHoverShouldSelect)
    }

    @Test("jitter below the arming distance does not arm")
    func jitterBelowArmingDistanceDoesNotArm() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let horizontalJitterShouldSelect = gate.shouldSelect(at: CGPoint(x: 102, y: 100))
        let verticalJitterShouldSelect = gate.shouldSelect(at: CGPoint(x: 100, y: 98))
        let diagonalJitterShouldSelect = gate.shouldSelect(at: CGPoint(x: 98, y: 102))

        #expect(!horizontalJitterShouldSelect)
        #expect(!verticalJitterShouldSelect)
        #expect(!diagonalJitterShouldSelect)
    }

    @Test("movement at the arming distance arms and selects")
    func movementAtArmingDistanceArmsAndSelects() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let shouldSelect = gate.shouldSelect(at: CGPoint(x: 104, y: 100))

        #expect(shouldSelect)
    }

    @Test("arming distance is measured euclidean, not per axis")
    func armingDistanceIsMeasuredEuclidean() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let shouldSelect = gate.shouldSelect(at: CGPoint(x: 103, y: 103))

        #expect(shouldSelect)
    }

    @Test("gate stays armed after the pointer returns to the origin")
    func gateStaysArmedAfterReturningToOrigin() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let movementShouldSelect = gate.shouldSelect(at: CGPoint(x: 200, y: 200))
        let returnShouldSelect = gate.shouldSelect(at: CGPoint(x: 100, y: 100))

        #expect(movementShouldSelect)
        #expect(returnShouldSelect)
    }

    @Test("gradual drift arms once it strays far enough from the origin")
    func gradualDriftArmsOnceFarEnoughFromOrigin() {
        var gate = HoverSelectionGate(initialPointerLocation: CGPoint(x: 100, y: 100))

        let initialDriftShouldSelect = gate.shouldSelect(at: CGPoint(x: 102, y: 100))
        let sufficientDriftShouldSelect = gate.shouldSelect(at: CGPoint(x: 104, y: 100))

        #expect(!initialDriftShouldSelect)
        #expect(sufficientDriftShouldSelect)
    }

    @Test("custom arming distance is respected")
    func customArmingDistanceIsRespected() {
        var gate = HoverSelectionGate(
            initialPointerLocation: CGPoint(x: 0, y: 0),
            armingDistance: 10
        )

        let belowThresholdShouldSelect = gate.shouldSelect(at: CGPoint(x: 9, y: 0))
        let thresholdShouldSelect = gate.shouldSelect(at: CGPoint(x: 10, y: 0))

        #expect(!belowThresholdShouldSelect)
        #expect(thresholdShouldSelect)
    }
}
