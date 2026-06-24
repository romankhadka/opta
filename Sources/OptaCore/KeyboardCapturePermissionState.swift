public struct KeyboardCapturePermissionState: Equatable, Sendable {
    public let accessibilityGranted: Bool
    public let inputMonitoringGranted: Bool

    public init(accessibilityGranted: Bool, inputMonitoringGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
    }

    public var canCaptureKeyboard: Bool {
        accessibilityGranted && inputMonitoringGranted
    }

    public var missingPermissionNames: [String] {
        var names: [String] = []

        if !accessibilityGranted {
            names.append("Accessibility")
        }

        if !inputMonitoringGranted {
            names.append("Input Monitoring")
        }

        return names
    }
}
