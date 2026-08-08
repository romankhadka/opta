import Testing

@testable import OptaCore

@Suite("WindowActivationPlan")
struct WindowActivationPlanTests {
    @Test("raises the selected window before the application is activated")
    func raisesBeforeActivating() throws {
        let steps = WindowActivationPlan.steps

        let raiseIndex = try #require(steps.firstIndex(of: .raiseWindow))
        let activateIndex = try #require(steps.firstIndex(of: .activateApplication))

        #expect(raiseIndex < activateIndex)
    }

    @Test("activates the application exactly once")
    func activatesOnce() {
        let activations = WindowActivationPlan.steps.filter { $0 == .activateApplication }

        #expect(activations.count == 1)
    }

    @Test("focuses the selected window after the application is activated")
    func focusesAfterActivating() throws {
        let steps = WindowActivationPlan.steps

        let activateIndex = try #require(steps.firstIndex(of: .activateApplication))

        #expect(steps.suffix(from: activateIndex).contains(.focusWindow))
    }
}
