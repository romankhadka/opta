import Foundation
import Testing

@Suite("Switcher preview cache performance")
struct SwitcherPreviewCachePerformanceTests {
    @Test("retains previews and icons briefly while cancelling stale capture work")
    func retainsSwitcherAssetsBrieflyWhileCancellingStaleCaptureWork() throws {
        let overlay = try source(at: "Sources/Opta/SwitcherOverlayController.swift")
        let previewProvider = try source(at: "Sources/Opta/WindowPreviewProvider.swift")

        #expect(overlay.contains("previewCacheExpirationTask"))
        #expect(overlay.contains("Task.sleep(for: .seconds(2))"))
        #expect(overlay.contains("previewCacheExpirationTask?.cancel()"))
        #expect(overlay.contains("previewProvider.cancelPendingRefreshes()"))
        #expect(previewProvider.contains("func cancelPendingRefreshes()"))
        #expect(previewProvider.contains("guard !Task.isCancelled, cacheGeneration == generation"))
        #expect(previewProvider.contains("private var cachedIcons"))
        #expect(previewProvider.contains("cachedIcons[processIdentifier]"))
        #expect(previewProvider.contains("cachedIcons.removeAll()"))
    }

    private func source(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }
}
