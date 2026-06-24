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

    @Test("checkbox title reflects the enabled state")
    func checkboxTitleReflectsEnabledState() {
        let store = StubShortcutStore(isEnabled: true)
        let controller = CurrentApplicationShortcutController(store: store)

        #expect(controller.checkboxTitle == "☑ Cycle Current App (⌥`)")

        controller.setEnabled(false)
        #expect(controller.checkboxTitle == "☐ Cycle Current App (⌥`)")
    }
}

private final class StubShortcutStore: CurrentApplicationShortcutStoring {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}
