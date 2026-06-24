public protocol CurrentApplicationShortcutStoring: AnyObject {
    var isEnabled: Bool { get set }
}

public final class CurrentApplicationShortcutController {
    private let store: CurrentApplicationShortcutStoring

    public init(store: CurrentApplicationShortcutStoring) {
        self.store = store
    }

    public var isEnabled: Bool {
        store.isEnabled
    }

    public var checkboxTitle: String {
        isEnabled ? "☑ Cycle Current App (⌥`)" : "☐ Cycle Current App (⌥`)"
    }

    public func setEnabled(_ isEnabled: Bool) {
        store.isEnabled = isEnabled
    }

    public func toggle() {
        setEnabled(!isEnabled)
    }
}
