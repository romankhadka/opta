import Testing

@testable import OptaCore

@Suite("Focus observation policy")
struct FocusObservationPolicyTests {
    @Test("records a focus notification from the frontmost application")
    func recordsNotificationFromFrontmostApplication() {
        #expect(
            FocusObservationPolicy.shouldRecordNotification(
                fromProcessIdentifier: 100,
                frontmostProcessIdentifier: 100
            )
        )
    }

    @Test("ignores a focus notification from a background application")
    func ignoresNotificationFromBackgroundApplication() {
        // A background app that closes a window or opens a document without
        // activating moves its own focus; that window must not outrank the
        // window the user is in.
        #expect(
            !FocusObservationPolicy.shouldRecordNotification(
                fromProcessIdentifier: 100,
                frontmostProcessIdentifier: 101
            )
        )
        #expect(
            !FocusObservationPolicy.shouldRecordNotification(
                fromProcessIdentifier: 100,
                frontmostProcessIdentifier: nil
            )
        )
    }

    @Test("retries a launching application that refused the registration")
    func retriesWhenRegistrationIsIncomplete() {
        #expect(
            FocusObservationPolicy.shouldRetry(
                attempt: 0,
                registrationIsComplete: false,
                focusedWindowRead: .notReady,
                isFrontmost: true
            )
        )
        #expect(
            FocusObservationPolicy.shouldRetry(
                attempt: 0,
                registrationIsComplete: false,
                focusedWindowRead: .window(7),
                isFrontmost: true
            )
        )
    }

    @Test("retries a registered application whose focused window was not readable yet")
    func retriesWhenFocusedWindowIsNotReady() {
        #expect(
            FocusObservationPolicy.shouldRetry(
                attempt: 3,
                registrationIsComplete: true,
                focusedWindowRead: .notReady,
                isFrontmost: true
            )
        )
    }

    @Test("stops once the application is registered and answered")
    func stopsWhenObservationSucceeded() {
        #expect(
            !FocusObservationPolicy.shouldRetry(
                attempt: 0,
                registrationIsComplete: true,
                focusedWindowRead: .window(7),
                isFrontmost: true
            )
        )
        // An app with no window yet reports it through a notification later.
        #expect(
            !FocusObservationPolicy.shouldRetry(
                attempt: 0,
                registrationIsComplete: true,
                focusedWindowRead: .none,
                isFrontmost: true
            )
        )
    }

    @Test("stops when the user left the application")
    func stopsWhenApplicationIsNoLongerFrontmost() {
        #expect(
            !FocusObservationPolicy.shouldRetry(
                attempt: 0,
                registrationIsComplete: false,
                focusedWindowRead: .notReady,
                isFrontmost: false
            )
        )
    }

    @Test("stops after the retry budget")
    func stopsAfterRetryBudget() {
        let lastAttempt = FocusObservationPolicy.maximumRetryCount

        #expect(
            FocusObservationPolicy.shouldRetry(
                attempt: lastAttempt - 1,
                registrationIsComplete: false,
                focusedWindowRead: .notReady,
                isFrontmost: true
            )
        )
        #expect(
            !FocusObservationPolicy.shouldRetry(
                attempt: lastAttempt,
                registrationIsComplete: false,
                focusedWindowRead: .notReady,
                isFrontmost: true
            )
        )
    }
}
