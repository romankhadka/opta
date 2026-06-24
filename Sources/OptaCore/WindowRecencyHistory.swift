public final class WindowRecencyHistory {
    private var recentWindowIDs: [UInt32] = []

    public init() {}

    public func record(windowID: UInt32) {
        recentWindowIDs.removeAll { $0 == windowID }
        recentWindowIDs.insert(windowID, at: 0)
    }

    public func sorted(_ windows: [WindowSnapshot]) -> [WindowSnapshot] {
        windows.enumerated()
            .sorted { firstWindow, secondWindow in
                let firstExplicitRank = explicitRank(for: firstWindow.element.id)
                let secondExplicitRank = explicitRank(for: secondWindow.element.id)

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

    private func explicitRank(for windowID: UInt32) -> Int? {
        recentWindowIDs.firstIndex(of: windowID)
    }
}
