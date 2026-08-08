import Testing

@testable import OptaCore

@Suite("Window activation plan")
struct WindowActivationPlanTests {
    @Test("raises the selected window before the application is activated")
    func raisesBeforeActivating() throws {
        let performer = RecordingWindowActivationPerformer()

        WindowActivationPlan.activate(using: performer)

        let raiseIndex = try #require(performer.steps.firstIndex(of: .raiseWindow))
        let activateIndex = try #require(performer.steps.firstIndex(of: .activateApplication))

        #expect(raiseIndex < activateIndex)
    }

    @Test("activates the application exactly once")
    func activatesOnce() {
        let performer = RecordingWindowActivationPerformer()

        WindowActivationPlan.activate(using: performer)

        #expect(performer.steps.filter { $0 == .activateApplication }.count == 1)
    }

    @Test("focuses the selected window after the application is activated")
    func focusesAfterActivating() throws {
        let performer = RecordingWindowActivationPerformer()

        WindowActivationPlan.activate(using: performer)

        let activateIndex = try #require(performer.steps.firstIndex(of: .activateApplication))

        #expect(performer.steps.suffix(from: activateIndex).contains(.focusWindow))
    }
}

private final class RecordingWindowActivationPerformer: WindowActivationPerforming {
    enum Step {
        case raiseWindow
        case focusWindow
        case activateApplication
    }

    private(set) var steps: [Step] = []

    func raiseWindow() {
        steps.append(.raiseWindow)
    }

    func focusWindow() {
        steps.append(.focusWindow)
    }

    func activateApplication() {
        steps.append(.activateApplication)
    }
}
