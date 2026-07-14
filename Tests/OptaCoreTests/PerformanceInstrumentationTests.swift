import Foundation
import Testing

@Suite("Performance instrumentation")
struct PerformanceInstrumentationTests {
    @Test("records the critical switcher intervals")
    func recordsCriticalSwitcherIntervals() throws {
        let metricsPath = "Sources/Opta/PerformanceMetrics.swift"
        let metricsExist = FileManager.default.fileExists(atPath: metricsPath)
        #expect(metricsExist)

        guard metricsExist else {
            return
        }

        let metrics = try source(at: metricsPath)
        let appDelegate = try source(at: "Sources/Opta/AppDelegate.swift")
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")
        let previewProvider = try source(at: "Sources/Opta/WindowPreviewProvider.swift")
        let windowProvider = try source(at: "Sources/Opta/SystemWindowProvider.swift")
        let activator = try source(at: "Sources/Opta/WindowActivator.swift")

        #expect(metrics.contains("OSSignposter"))
        #expect(metrics.contains("category: .pointsOfInterest"))
        #expect(appDelegate.contains("PerformanceMetrics.begin(\"CycleAllApplications\")"))
        #expect(appDelegate.contains("PerformanceMetrics.begin(\"CycleActiveSession\")"))
        #expect(overlay.contains("PerformanceMetrics.begin(\"OverlayRender\")"))
        #expect(previewProvider.contains("PerformanceMetrics.begin(\"PreviewRefresh\")"))
        #expect(previewProvider.contains("PerformanceMetrics.begin(\"IconLookup\")"))
        #expect(windowProvider.contains("PerformanceMetrics.begin(\"WindowDiscovery\")"))
        #expect(activator.contains("PerformanceMetrics.begin(\"WindowActivation\")"))
        #expect(activator.contains("PerformanceMetrics.begin(\"WindowMatch\")"))
        #expect(activator.contains("PerformanceMetrics.begin(\"WindowFocusActions\")"))
    }

    private func source(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
