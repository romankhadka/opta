import AppKit
import OptaCore
import ScreenCaptureKit

@MainActor
final class WindowPreviewProvider {
    // The switcher shows previews in 138x86-point tiles (see SwitcherLayout),
    // so no capture needs more pixels than a Retina tile. Capturing beyond
    // that -- a full-screen window can be over 100x the pixel count -- only
    // slows the switcher down for identical on-screen quality.
    private static let previewFillPixelWidth: CGFloat = 276
    private static let previewFillPixelHeight: CGFloat = 172
    // Never capture above native Retina resolution; upscaling tiny windows
    // adds pixels without adding detail.
    private static let maximumCaptureScale: CGFloat = 2

    private var cachedPreviews: [UInt32: NSImage] = [:]
    private var cacheGeneration = 0

    func preview(for window: WindowSnapshot) -> NSImage? {
        cachedPreviews[window.id]
    }

    func icon(for window: WindowSnapshot) -> NSImage? {
        NSRunningApplication(processIdentifier: pid_t(window.processIdentifier))?.icon
    }

    func invalidate() {
        cacheGeneration += 1
        cachedPreviews.removeAll()
    }

    func refreshPreviews(for windows: [WindowSnapshot]) async -> Bool {
        let missingWindows = windows.filter { cachedPreviews[$0.id] == nil }
        guard !missingWindows.isEmpty else {
            return false
        }

        guard let shareableContent = try? await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        ) else {
            return false
        }

        // Read after the await so an invalidate() during the content fetch
        // also discards these captures instead of repopulating a cleared cache.
        let generation = cacheGeneration
        let shareableWindowsByID = Dictionary(
            shareableContent.windows.map { ($0.windowID, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Start every capture before awaiting any, so ScreenCaptureKit works
        // on all windows concurrently instead of one at a time. Each task
        // inherits the main actor, keeping cache writes serialized while the
        // awaits merely suspend.
        let captureTasks = missingWindows.compactMap { window -> Task<Bool, Never>? in
            guard let shareableWindow = shareableWindowsByID[CGWindowID(window.id)] else {
                return nil
            }

            return Task {
                guard let preview = try? await self.capturePreview(for: shareableWindow),
                      self.cacheGeneration == generation else {
                    return false
                }

                self.cachedPreviews[window.id] = preview
                return true
            }
        }

        var didUpdate = false
        for task in captureTasks {
            didUpdate = await task.value || didUpdate
        }

        return didUpdate
    }

    private func capturePreview(for window: SCWindow) async throws -> NSImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()

        let frame = window.frame
        let fillScale = max(
            Self.previewFillPixelWidth / max(frame.width, 1),
            Self.previewFillPixelHeight / max(frame.height, 1)
        )
        let captureScale = min(fillScale, Self.maximumCaptureScale)
        configuration.width = max(1, Int((frame.width * captureScale).rounded(.up)))
        configuration.height = max(1, Int((frame.height * captureScale).rounded(.up)))
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
