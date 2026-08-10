/// The Option key mark, which Opta draws both as its application icon and as
/// its menu bar item.
///
/// The two are the same shape at very different sizes, so the geometry lives
/// here once and each drawing site supplies its own stroke weight. Points are
/// on the 1024-unit canvas the icon document uses, with y increasing downward
/// so the values read the same here as they do in the SVG.
public enum OptionMark {
    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Bounds: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
    }

    /// The edge length of the canvas the mark is laid out on.
    public static let canvas: Double = 1024

    /// The line that runs on: in from the left, down through the switch, and
    /// out to the right.
    public static let throughLine: [Point] = [
        Point(x: 268, y: 356),
        Point(x: 462, y: 356),
        Point(x: 636, y: 668),
        Point(x: 756, y: 668),
    ]

    /// The track the switch hands you off to.
    public static let branch: [Point] = [
        Point(x: 660, y: 356),
        Point(x: 756, y: 356),
    ]

    /// The weight the application icon is drawn at. Chosen against the
    /// 16-point rendition: lighter and the mark loses authority, heavier and it
    /// crowds the squircle.
    public static let applicationStrokeWidth: Double = 96

    /// The menu bar item is drawn near 18 points wide, where the application
    /// icon's weight closes the gap between the branch and the through line and
    /// reads as a blob beside the system's own items.
    public static let menuBarStrokeWidth: Double = 72

    /// The mark's outer bounds at a given weight, stroke included.
    ///
    /// Round caps and joins both stay within half the stroke width of the path,
    /// so the stroke expands the path's box evenly on every side.
    public static func bounds(strokeWidth: Double) -> Bounds {
        let points = throughLine + branch
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let inset = strokeWidth / 2

        return Bounds(
            x: minX - inset,
            y: minY - inset,
            width: (maxX - minX) + strokeWidth,
            height: (maxY - minY) + strokeWidth
        )
    }

    /// The stroke as SVG path data, so the icon document and this geometry can
    /// be checked against each other rather than drifting apart.
    public static func pathData(_ points: [Point]) -> String {
        points.enumerated()
            .map { index, point in
                let command = index == 0 ? "M" : "L"
                return "\(command)\(format(point.x)) \(format(point.y))"
            }
            .joined(separator: " ")
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
