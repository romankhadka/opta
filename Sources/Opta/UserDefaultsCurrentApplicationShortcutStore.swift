import Foundation
import OptaCore

final class UserDefaultsCurrentApplicationShortcutStore: CurrentApplicationShortcutStoring {
    private static let key = "currentApplicationShortcutEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Cycling the current application with ⌥` is on by default; users who
        // type grave-accented characters (à, è, ì, ò, ù) can turn it off so the
        // dead key passes through to the focused app.
        defaults.register(defaults: [Self.key: true])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }
}
