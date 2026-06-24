import AppKit
import OptaCore
import ScreenCaptureKit

@MainActor
final class WindowPreviewProvider {
    private var cachedPreviews: [UInt32: NSImage] = [:]

    func preview(for window: WindowSnapshot) -> NSImage? {
        cachedPreviews[window.id]
    }

    func icon(for window: WindowSnapshot) -> NSImage? {
        NSRunningApplication(processIdentifier: pid_t(window.processIdentifier))?.icon
    }

    func refreshPreviews(for windows: [WindowSnapshot]) async -> Bool {
        let missingWindows = windows.filter { cachedPreviews[$0.id] == nil }
        guard !missingWindows.isEmpty else {
            return false
        }

        do {
            let shareableContent = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            let shareableWindowsByID = Dictionary(
                uniqueKeysWithValues: shareableContent.windows.map { ($0.windowID, $0) }
            )
            var didUpdate = false

            for window in missingWindows {
                guard
                    let shareableWindow = shareableWindowsByID[CGWindowID(window.id)],
                    let preview = try await capturePreview(for: shareableWindow)
                else {
                    continue
                }

                cachedPreviews[window.id] = preview
                didUpdate = true
            }

            return didUpdate
        } catch {
            return false
        }
    }

    private func capturePreview(for window: SCWindow) async throws -> NSImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(window.frame.width))
        configuration.height = max(1, Int(window.frame.height))
        configuration.showsCursor = false
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.ignoreShadowsSingleWindow = true
        configuration.shouldBeOpaque = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        return NSImage(cgImage: image, size: .zero)
    }
}
