/// Decides when closing a window should move focus to the most recently used
/// window of another application.
///
/// macOS already focuses an application's next window when one of several
/// closes, so Opta acts only when the application is left with no window at
/// all. macOS then keeps the empty application frontmost, and the user has to
/// click or switch to get back to what they were doing.
public enum FocusFollowsClosePolicy {
    /// Applications whose closing windows never move focus. Launchers and
    /// panels close their window as they hand focus to something else.
    public static let ignoredApplicationNames: Set<String> = [
        "Hammerspoon",
        "Spotlight",
        "Alfred",
    ]

    /// Whether a window close qualifies. The caller then checks that the
    /// application has no standard window left, which needs a round trip to
    /// the application, so it runs only for a close that qualifies.
    ///
    /// closedInProcessIdentifier  - The process that owned the closed window.
    /// frontmostProcessIdentifier - The process that is frontmost now. A close
    ///                              in any other process is a background close
    ///                              or follows an application switch.
    /// applicationName            - The closing application's name.
    public static func shouldHandleClose(
        closedInProcessIdentifier: Int32,
        frontmostProcessIdentifier: Int32?,
        applicationName: String?
    ) -> Bool {
        guard closedInProcessIdentifier == frontmostProcessIdentifier else {
            return false
        }

        guard let applicationName else {
            return true
        }

        return !ignoredApplicationNames.contains(applicationName)
    }
}
