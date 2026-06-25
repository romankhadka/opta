import Testing

@testable import OptaCore

@Suite("Current application shortcut")
struct CurrentApplicationShortcutControllerTests {
    @Test("toggling flips the stored preference")
    func togglingFlipsStoredPreference() {
        let store = StubShortcutStore(isEnabled: true)
        let controller = CurrentApplicationShortcutController(store: store)

        controller.toggle()
        #expect(!controller.isEnabled)
        #expect(!store.isEnabled)

        controller.toggle()
        #expect(controller.isEnabled)
        #expect(store.isEnabled)
    }

    @Test("setEnabled writes through to the store")
    func setEnabledWritesThroughToStore() {
        let store = StubShortcutStore(isEnabled: true)
        let controller = CurrentApplicationShortcutController(store: store)

        controller.setEnabled(false)

        #expect(!controller.isEnabled)
        #expect(!store.isEnabled)
    }

    @Test("isEnabled reflects the stored preference")
    func isEnabledReflectsStoredPreference() {
        let store = StubShortcutStore(isEnabled: true)
        let controller = CurrentApplicationShortcutController(store: store)

        #expect(controller.isEnabled)

        controller.setEnabled(false)
        #expect(!controller.isEnabled)
    }
}

private final class StubShortcutStore: CurrentApplicationShortcutStoring {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
