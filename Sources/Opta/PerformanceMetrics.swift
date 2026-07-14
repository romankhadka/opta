import OSLog

enum PerformanceMetrics {
    private static let signposter = OSSignposter(
        subsystem: "io.github.romankhadka.opta",
        category: .pointsOfInterest
    )

    struct Interval {
        fileprivate let name: StaticString
        fileprivate let state: OSSignpostIntervalState
    }

    static func begin(_ name: StaticString) -> Interval {
        let signpostID = signposter.makeSignpostID()
        return Interval(
            name: name,
            state: signposter.beginInterval(name, id: signpostID)
        )
    }

    static func end(_ interval: Interval) {
        signposter.endInterval(interval.name, interval.state)
    }
}
