/// What reading an application's focused window produced.
public enum FocusedWindowRead: Equatable, Sendable {
    /// The focused window resolved to a window id.
    case window(UInt32)
    /// The application answered, but has no focused window Opta can use.
    case none
    /// The application did not answer, usually because it is still launching.
    case notReady
}

/// Decides which focus reports the focus tracker records, and when it tries
/// an application again.
public enum FocusObservationPolicy {
    /// A just-launched application refuses accessibility requests until its
    /// run loop is up, which took 0.3 to 1.3 seconds for TextEdit, Chess and
    /// Calculator. Retrying for up to five seconds covers slow launches.
    public static let retryInterval: Duration = .milliseconds(250)
    public static let maximumRetryCount = 20

    /// Accessibility posts focused-window and main-window notifications for
    /// background applications too, for example when a background app closes
    /// one of its windows or opens a document without activating. Recording
    /// those would rank a window the user never looked at above the window
    /// they are in, and the next switch would land on the current window.
    public static func shouldRecordNotification(
        fromProcessIdentifier processIdentifier: Int32,
        frontmostProcessIdentifier: Int32?
    ) -> Bool {
        processIdentifier == frontmostProcessIdentifier
    }

    /// Whether to observe the application again after `attempt` (zero-based).
    ///
    /// registrationIsComplete - Every focus notification is registered.
    /// focusedWindowRead      - What the last focused-window read produced.
    /// isFrontmost            - The application is still frontmost. A later
    ///                          activation starts a fresh round, so there is
    ///                          no reason to keep messaging an app the user
    ///                          already left.
    public static func shouldRetry(
        attempt: Int,
        registrationIsComplete: Bool,
        focusedWindowRead: FocusedWindowRead,
        isFrontmost: Bool
    ) -> Bool {
        guard isFrontmost, attempt < maximumRetryCount else {
            return false
        }

        return !registrationIsComplete || focusedWindowRead == .notReady
    }
}
