public struct WindowBounds: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct WindowSnapshot: Equatable, Identifiable, Sendable {
    public let id: UInt32
    public let processIdentifier: Int32
    public let applicationName: String
    public let title: String
    public let isOnscreen: Bool
    public let layer: Int
    public let bounds: WindowBounds
    public let recencyRank: Int

    public init(
        id: UInt32,
        processIdentifier: Int32,
        applicationName: String,
        title: String,
        isOnscreen: Bool,
        layer: Int,
        bounds: WindowBounds,
        recencyRank: Int
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.title = title
        self.isOnscreen = isOnscreen
        self.layer = layer
        self.bounds = bounds
        self.recencyRank = recencyRank
    }

    public var displayTitle: String {
        title.isEmpty ? "Untitled Window" : title
    }
}

public protocol WindowProviding {
    func availableWindows() -> [WindowSnapshot]
}

public enum WindowCycleScope: Equatable, Sendable {
    case allApplications
    case currentApplication(processIdentifier: Int32)
}

public enum WindowCycleDirection: Equatable, Sendable {
    case forward
    case backward
}

public struct WindowCycleSession: Equatable, Sendable {
    public let windows: [WindowSnapshot]
    public private(set) var selectedIndex: Int

    public init(windows: [WindowSnapshot], selectedIndex: Int = 0) {
        self.windows = windows
        self.selectedIndex = windows.indices.contains(selectedIndex) ? selectedIndex : 0
    }

    public var selectedWindow: WindowSnapshot? {
        guard windows.indices.contains(selectedIndex) else {
            return nil
        }

        return windows[selectedIndex]
    }

    public mutating func advance(_ direction: WindowCycleDirection = .forward) {
        guard !windows.isEmpty else {
            return
        }

        switch direction {
        case .forward:
            selectedIndex = (selectedIndex + 1) % windows.count
        case .backward:
            selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        }
    }

    @discardableResult
    public mutating func select(windowID: UInt32) -> Bool {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else {
            return false
        }

        selectedIndex = index
        return true
    }
}

public final class WindowCycler {
    private let provider: WindowProviding
    private let recencyHistory: WindowRecencyHistory?

    public init(provider: WindowProviding, recencyHistory: WindowRecencyHistory? = nil) {
        self.provider = provider
        self.recencyHistory = recencyHistory
    }

    public func start(scope: WindowCycleScope) -> WindowCycleSession {
        let cyclableWindows = provider.availableWindows().filter(\.isCyclable)
        recencyHistory?.observeWindowsFocusedOutsideOpta(cyclableWindows)
        let sortedWindows = recencyHistory?.sorted(cyclableWindows) ?? cyclableWindows.stableSortedByRecentUse()
        let windows = sortedWindows
            .filter { window in
                switch scope {
                case .allApplications:
                    true
                case .currentApplication(let processIdentifier):
                    window.processIdentifier == processIdentifier
                }
            }

        return WindowCycleSession(windows: windows)
    }
}

public final class SwitcherCoordinator {
    private let cycler: WindowCycler
    private var activeScope: WindowCycleScope?

    public private(set) var activeSession: WindowCycleSession?

    public init(cycler: WindowCycler) {
        self.cycler = cycler
    }

    @discardableResult
    public func press(
        scope: WindowCycleScope,
        direction: WindowCycleDirection = .forward
    ) -> WindowCycleSession {
        if activeScope == scope, var session = activeSession {
            session.advance(direction)
            activeSession = session
            return session
        }

        var session = cycler.start(scope: scope)
        if session.windows.count > 1 {
            session.advance(direction)
        }

        activeScope = scope
        activeSession = session
        return session
    }

    @discardableResult
    public func select(windowID: UInt32) -> WindowCycleSession? {
        guard var session = activeSession, session.select(windowID: windowID) else {
            return activeSession
        }

        activeSession = session
        return session
    }

    @discardableResult
    public func advanceActiveSession(_ direction: WindowCycleDirection) -> WindowCycleSession? {
        guard var session = activeSession else {
            return nil
        }

        session.advance(direction)
        activeSession = session
        return session
    }

    public func release() -> WindowSnapshot? {
        defer {
            activeScope = nil
            activeSession = nil
        }

        return activeSession?.selectedWindow
    }

    public func cancel() {
        activeScope = nil
        activeSession = nil
    }
}

private extension Array where Element == WindowSnapshot {
    func stableSortedByRecentUse() -> [WindowSnapshot] {
        enumerated()
            .sorted { firstWindow, secondWindow in
                if firstWindow.element.recencyRank == secondWindow.element.recencyRank {
                    firstWindow.offset < secondWindow.offset
                } else {
                    firstWindow.element.recencyRank < secondWindow.element.recencyRank
                }
            }
            .map(\.element)
    }
}

private extension WindowSnapshot {
    var isCyclable: Bool {
        isOnscreen &&
            layer == 0 &&
            bounds.width > 0 &&
            bounds.height > 0
    }
}
