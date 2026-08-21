import Testing

@testable import OptaCore

@Suite("Keyboard capture startup policy")
struct KeyboardCaptureStartupPolicyTests {
    private let policy = KeyboardCaptureStartupPolicy()

    private let granted = KeyboardCapturePermissionState(
        accessibilityGranted: true,
        inputMonitoringGranted: true
    )
    private let denied = KeyboardCapturePermissionState(
        accessibilityGranted: false,
        inputMonitoringGranted: false
    )

    @Test("a granted permission with no tap installs one")
    func grantedPermissionStartsTheTap() {
        #expect(
            policy.step(permissionState: granted, tapIsRunning: false, helpWasShown: false) == .startTap
        )
        #expect(
            policy.step(permissionState: granted, tapIsRunning: false, helpWasShown: true) == .startTap
        )
    }

    @Test("a running tap under a granted permission is left alone")
    func runningTapStaysIdle() {
        #expect(
            policy.step(permissionState: granted, tapIsRunning: true, helpWasShown: false) == .idle
        )
    }

    @Test("the help is shown once, then the policy keeps waiting for the grant")
    func missingPermissionShowsHelpOnceThenWaits() {
        #expect(
            policy.step(permissionState: denied, tapIsRunning: false, helpWasShown: false)
                == .showHelpAndWait
        )
        #expect(
            policy.step(permissionState: denied, tapIsRunning: false, helpWasShown: true) == .wait
        )
    }

    @Test("waiting turns into a tap as soon as the user grants the permission")
    func waitingRecoversWhenPermissionArrives() {
        #expect(
            policy.step(permissionState: denied, tapIsRunning: false, helpWasShown: true) == .wait
        )
        #expect(
            policy.step(permissionState: granted, tapIsRunning: false, helpWasShown: true) == .startTap
        )
    }

    @Test("a permission revoked under a live tap tears the dead tap down")
    func revokedPermissionStopsTheTap() {
        #expect(
            policy.step(permissionState: denied, tapIsRunning: true, helpWasShown: false) == .stopTap
        )
        #expect(
            policy.step(permissionState: denied, tapIsRunning: true, helpWasShown: true) == .stopTap
        )
    }

    @Test("a partial grant is treated as no grant")
    func partialPermissionKeepsWaiting() {
        let accessibilityOnly = KeyboardCapturePermissionState(
            accessibilityGranted: true,
            inputMonitoringGranted: false
        )

        #expect(
            policy.step(permissionState: accessibilityOnly, tapIsRunning: false, helpWasShown: true)
                == .wait
        )
        #expect(
            policy.step(permissionState: accessibilityOnly, tapIsRunning: true, helpWasShown: true)
                == .stopTap
        )
    }
}
