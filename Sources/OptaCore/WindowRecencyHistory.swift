public final class WindowRecencyHistory {
    private var recentWindowIDs: [UInt32] = []
    private var observedWindowIDs: Set<UInt32> = []
    private var didObserveWindows = false

    public init() {}

    public func record(windowID: UInt32) {
        recentWindowIDs.removeAll { $0 == windowID }
        recentWindowIDs.insert(windowID, at: 0)
    }

    public func sorted(_ windows: [WindowSnapshot]) -> [WindowSnapshot] {
        let rankByID = Dictionary(
            uniqueKeysWithValues: recentWindowIDs.enumerated().map { ($1, $0) }
        )

        return windows.enumerated()
            .sorted { firstWindow, secondWindow in
                let firstExplicitRank = rankByID[firstWindow.element.id]
                let secondExplicitRank = rankByID[secondWindow.element.id]

                switch (firstExplicitRank, secondExplicitRank) {
                case let (firstRank?, secondRank?):
                    if firstRank != secondRank {
                        return firstRank < secondRank
                    }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    if firstWindow.element.recencyRank != secondWindow.element.recencyRank {
                        return firstWindow.element.recencyRank < secondWindow.element.recencyRank
                    }
                }

                return firstWindow.offset < secondWindow.offset
            }
            .map(\.element)
    }

    /// Folds windows that appeared since the last observation into the recency log.
    ///
    /// A window we have not observed before became frontmost through some action
    /// outside Opta — it was opened, or clicked directly. The system stacking
    /// order reflects that, but the explicit log would not, so the window would
    /// sink below every stale recorded window once it is no longer brand new.
    /// Promoting it here keeps the log the single source of truth: newly focused
    /// windows enter at the top, ordered front-most first, just as if Opta had
    /// activated them. Call once per observation, before `sorted(_:)`.
    public func observeWindowsFocusedOutsideOpta(_ windows: [WindowSnapshot]) {
        let currentWindowIDs = Set(windows.map(\.id))
        defer {
            observedWindowIDs = currentWindowIDs
            didObserveWindows = true
        }

        guard didObserveWindows else {
            return
        }

        let newlyObservedWindowIDs = currentWindowIDs.subtracting(observedWindowIDs)
        let newlyObservedFrontMostFirst = windows
            .filter { newlyObservedWindowIDs.contains($0.id) }
            .sorted { $0.recencyRank < $1.recencyRank }

        // Insert from the back so the front-most newly observed window ends up at
        // the head of the log, above anything Opta recorded earlier.
        for window in newlyObservedFrontMostFirst.reversed() {
            record(windowID: window.id)
        }
    }
}
