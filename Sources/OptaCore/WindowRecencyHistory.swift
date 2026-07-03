public final class WindowRecencyHistory {
    private var recentWindowIDs: [UInt32] = []
    private var lastObservedFrontmostWindowID: UInt32?

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

    /// Promotes the window the system currently shows as frontmost into the
    /// recency log when it differs from what Opta last observed.
    ///
    /// The system's front-to-back window order changes for reasons Opta never
    /// sees directly — a Dock click, Cmd+Tab, or (as with clicking a link in a
    /// terminal) one app asking another to raise a window it already had open.
    /// Tracking only "is this window ID new" misses that last case, since the
    /// window isn't new — it just regained focus outside Opta. Comparing
    /// frontmost identity across calls catches both: a new window is frontmost
    /// by construction, and an existing window regaining focus changes who's
    /// frontmost too. Call once per observation, before `sorted(_:)`.
    public func observeWindowsFocusedOutsideOpta(_ windows: [WindowSnapshot]) {
        guard let currentFrontmost = windows.min(by: { $0.recencyRank < $1.recencyRank }) else {
            return
        }
        defer {
            lastObservedFrontmostWindowID = currentFrontmost.id
        }

        guard let lastObservedFrontmostWindowID, lastObservedFrontmostWindowID != currentFrontmost.id else {
            return
        }

        record(windowID: currentFrontmost.id)
    }
}
