public struct WindowActivationCandidate: Equatable, Sendable {
    public let windowNumber: UInt32?
    public let title: String
    public let bounds: WindowBounds?
    public let order: Int?

    public init(windowNumber: UInt32?, title: String, bounds: WindowBounds?, order: Int? = nil) {
        self.windowNumber = windowNumber
        self.title = title
        self.bounds = bounds
        self.order = order
    }
}

public enum WindowActivationMatcher {
    public static func bestMatch(
        for window: WindowSnapshot,
        candidates: [WindowActivationCandidate],
        targetOrder: Int? = nil
    ) -> WindowActivationCandidate? {
        if let numberMatch = candidates.first(where: { $0.windowNumber == window.id }) {
            return numberMatch
        }

        return candidates
            .compactMap { candidate -> (candidate: WindowActivationCandidate, score: Int)? in
                guard let score = score(candidate: candidate, for: window, targetOrder: targetOrder) else {
                    return nil
                }

                return (candidate: candidate, score: score)
            }
            .max { firstMatch, secondMatch in
                firstMatch.score < secondMatch.score
            }?
            .candidate
    }

    private static func score(
        candidate: WindowActivationCandidate,
        for window: WindowSnapshot,
        targetOrder: Int?
    ) -> Int? {
        var score = 0

        if !window.title.isEmpty, !candidate.title.isEmpty {
            guard candidate.title == window.title else {
                return nil
            }

            score += 100
        }

        if let candidateBounds = candidate.bounds, boundsMatch(candidateBounds, window.bounds) {
            score += 50
        }

        if let targetOrder, candidate.order == targetOrder {
            score += 25
        }

        return score > 0 ? score : nil
    }

    private static func boundsMatch(_ firstBounds: WindowBounds, _ secondBounds: WindowBounds) -> Bool {
        let tolerance = 4.0

        return abs(firstBounds.x - secondBounds.x) <= tolerance &&
            abs(firstBounds.y - secondBounds.y) <= tolerance &&
            abs(firstBounds.width - secondBounds.width) <= tolerance &&
            abs(firstBounds.height - secondBounds.height) <= tolerance
    }
}
