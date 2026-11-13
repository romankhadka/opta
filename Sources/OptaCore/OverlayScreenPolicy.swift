import CoreGraphics

/// Picks the display that shows the switcher overlay.
///
/// The overlay belongs on the display of the active window, not the display
/// under the pointer: with several monitors the pointer often rests on a
/// different display than the one the user works on.
public enum OverlayScreenPolicy {
    /// The index in `screenFrames` of the screen that holds the largest part
    /// of the window, or `nil` when no screen holds any part of it.
    ///
    /// - Parameters:
    ///   - windowBounds: The window frame in window-server coordinates: origin
    ///     at the top-left of the primary display, y grows down.
    ///   - screenFrames: Screen frames in AppKit coordinates: origin at the
    ///     bottom-left of the primary display, y grows up.
    ///   - primaryScreenHeight: The height of the primary display, which
    ///     relates the two coordinate spaces.
    public static func screenIndex(
        containing windowBounds: WindowBounds,
        screenFrames: [CGRect],
        primaryScreenHeight: CGFloat
    ) -> Int? {
        let windowFrame = CGRect(
            x: windowBounds.x,
            y: primaryScreenHeight - windowBounds.y - windowBounds.height,
            width: windowBounds.width,
            height: windowBounds.height
        )

        var bestIndex: Int?
        var bestArea: CGFloat = 0
        for (index, screenFrame) in screenFrames.enumerated() {
            let overlap = screenFrame.intersection(windowFrame)
            guard !overlap.isNull else {
                continue
            }

            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                bestIndex = index
            }
        }

        return bestIndex
    }
}
