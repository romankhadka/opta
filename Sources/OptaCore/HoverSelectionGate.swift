import CoreGraphics

/// Suppresses pointer-hover selection until the pointer actually moves.
///
/// The switcher overlay can materialize underneath a stationary cursor, which
/// makes hover tracking report the tile under the pointer even though the
/// user never touched the mouse. The gate records where the pointer was when
/// the session started and refuses hover selection until the pointer strays
/// beyond `armingDistance` from that point. Once armed it stays armed for the
/// lifetime of the gate, even if the pointer later returns to its origin.
public struct HoverSelectionGate: Equatable, Sendable {
    private let initialPointerLocation: CGPoint
    private let armingDistance: CGFloat
    private var isArmed = false

    public init(initialPointerLocation: CGPoint, armingDistance: CGFloat = 4) {
        self.initialPointerLocation = initialPointerLocation
        self.armingDistance = armingDistance
    }

    public mutating func shouldSelect(at location: CGPoint) -> Bool {
        if isArmed {
            return true
        }

        let dx = location.x - initialPointerLocation.x
        let dy = location.y - initialPointerLocation.y
        guard dx * dx + dy * dy >= armingDistance * armingDistance else {
            return false
        }

        isArmed = true
        return true
    }
}
