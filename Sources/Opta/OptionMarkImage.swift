import AppKit
import OptaCore

enum OptionMarkImage {
    /// The Option mark as a menu bar template image.
    ///
    /// Template images are drawn as a mask, so the stroke colour here does not
    /// survive: macOS re-tints the shape for the light and dark menu bar and
    /// for the pressed state. Sizing by width rather than height keeps the mark
    /// from growing past its neighbours, because the glyph is much wider than
    /// it is tall.
    static func menuBar(width: Double = 18) -> NSImage {
        let strokeWidth = OptionMark.menuBarStrokeWidth
        let bounds = OptionMark.bounds(strokeWidth: strokeWidth)
        let scale = width / bounds.width
        let size = NSSize(width: width, height: bounds.height * scale)

        let image = NSImage(size: size, flipped: true) { _ in
            let path = NSBezierPath()
            path.lineWidth = strokeWidth * scale
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            append(OptionMark.throughLine, to: path, within: bounds, scale: scale)
            append(OptionMark.branch, to: path, within: bounds, scale: scale)
            NSColor.black.setStroke()
            path.stroke()
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = "Opta"
        return image
    }

    private static func append(
        _ points: [OptionMark.Point],
        to path: NSBezierPath,
        within bounds: OptionMark.Bounds,
        scale: Double
    ) {
        for (index, point) in points.enumerated() {
            // The mark's canvas puts y at the top, which is also what a flipped
            // NSImage draws into, so the coordinates carry over unchanged.
            let placed = NSPoint(
                x: (point.x - bounds.x) * scale,
                y: (point.y - bounds.y) * scale
            )

            if index == 0 {
                path.move(to: placed)
            } else {
                path.line(to: placed)
            }
        }
    }
}
