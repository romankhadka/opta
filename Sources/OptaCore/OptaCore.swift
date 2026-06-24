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

    public init(
        id: UInt32,
        processIdentifier: Int32,
        applicationName: String,
        title: String,
        isOnscreen: Bool,
        layer: Int,
        bounds: WindowBounds
    ) {
        self.id = id
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.title = title
        self.isOnscreen = isOnscreen
        self.layer = layer
        self.bounds = bounds
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

    public mutating func advance() {
        guard !windows.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + 1) % windows.count
    }
}

public final class WindowCycler {
    private let provider: WindowProviding

    public init(provider: WindowProviding) {
        self.provider = provider
    }

    public func start(scope: WindowCycleScope) -> WindowCycleSession {
        let windows = provider.availableWindows()
            .filter(\.isCyclable)
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
    public func press(scope: WindowCycleScope) -> WindowCycleSession {
        if activeScope == scope, var session = activeSession {
            session.advance()
            activeSession = session
            return session
        }

        var session = cycler.start(scope: scope)
        if session.windows.count > 1 {
            session.advance()
        }

        activeScope = scope
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
}

private extension WindowSnapshot {
    var isCyclable: Bool {
        isOnscreen &&
            layer == 0 &&
            bounds.width > 0 &&
            bounds.height > 0
    }
}
