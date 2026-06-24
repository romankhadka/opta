import OSLog

extension Logger {
    /// All Opta loggers share this subsystem; the category distinguishes call sites.
    static func opta(category: String) -> Logger {
        Logger(subsystem: "io.github.romankhadka.opta", category: category)
    }
}
