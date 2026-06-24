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
        let currentWindowIDs = Set(windows.map(\.id))
        let newlyObservedWindowIDs = didObserveWindows ? currentWindowIDs.subtracting(observedWindowIDs) : []
        observedWindowIDs = currentWindowIDs
        didObserveWindows = true

        let rankByID = Dictionary(
            uniqueKeysWithValues: recentWindowIDs.enumerated().map { ($1, $0) }
        )

        return windows.enumerated()
            .sorted { firstWindow, secondWindow in
                let firstIsNewlyObserved = newlyObservedWindowIDs.contains(firstWindow.element.id)
                let secondIsNewlyObserved = newlyObservedWindowIDs.contains(secondWindow.element.id)
                if firstIsNewlyObserved || secondIsNewlyObserved {
                    if firstWindow.element.recencyRank != secondWindow.element.recencyRank {
                        return firstWindow.element.recencyRank < secondWindow.element.recencyRank
                    }
                }

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
}
