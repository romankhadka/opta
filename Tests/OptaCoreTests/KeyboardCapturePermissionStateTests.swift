import Testing

@testable import OptaCore

@Suite("Keyboard capture permission state")
struct KeyboardCapturePermissionStateTests {
    @Test("keyboard capture is ready only when accessibility and input monitoring are granted")
    func keyboardCaptureRequiresAccessibilityAndInputMonitoring() {
        #expect(
            KeyboardCapturePermissionState(
                accessibilityGranted: true,
                inputMonitoringGranted: true
            ).canCaptureKeyboard
        )
        #expect(
            !KeyboardCapturePermissionState(
                accessibilityGranted: false,
                inputMonitoringGranted: true
            ).canCaptureKeyboard
        )
        #expect(
            !KeyboardCapturePermissionState(
                accessibilityGranted: true,
                inputMonitoringGranted: false
            ).canCaptureKeyboard
        )
    }

    @Test("missing permission names are user visible")
    func missingPermissionNamesAreUserVisible() {
        let permissionState = KeyboardCapturePermissionState(
            accessibilityGranted: false,
            inputMonitoringGranted: false
        )

        #expect(permissionState.missingPermissionNames == ["Accessibility", "Input Monitoring"])
    }
}
