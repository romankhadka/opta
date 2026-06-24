import ApplicationServices
import OptaCore

final class KeyboardEventTap: @unchecked Sendable {
    private static let tabKeyCode: Int64 = 48
    private static let graveKeyCode: Int64 = 50
    private static let escapeKeyCode: Int64 = 53

    private let onCycleAllApplications: @MainActor @Sendable (WindowCycleDirection) -> Void
    private let onCycleCurrentApplication: @MainActor @Sendable (WindowCycleDirection) -> Void
    private let onModifierRelease: @MainActor @Sendable () -> Void
    private let onCancel: @MainActor @Sendable () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var optionWasDown = false
    // Written from the main actor, read on the event-tap callback; both run on
    // the main run loop, so the @unchecked Sendable access is single-threaded.
    private var sessionIsActive = false

    init(
        onCycleAllApplications: @escaping @MainActor @Sendable (WindowCycleDirection) -> Void,
        onCycleCurrentApplication: @escaping @MainActor @Sendable (WindowCycleDirection) -> Void,
        onModifierRelease: @escaping @MainActor @Sendable () -> Void,
        onCancel: @escaping @MainActor @Sendable () -> Void
    ) {
        self.onCycleAllApplications = onCycleAllApplications
        self.onCycleCurrentApplication = onCycleCurrentApplication
        self.onModifierRelease = onModifierRelease
        self.onCancel = onCancel
    }

    func setSessionActive(_ active: Bool) {
        sessionIsActive = active
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        let eventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: keyboardEventTapCallback,
            userInfo: context
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
            return false
        }

        self.eventTap = eventTap
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .flagsChanged {
            return handleFlagsChanged(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        return handleKeyDown(event)
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let optionIsDown = event.flags.contains(.maskAlternate)
        if optionWasDown && !optionIsDown {
            optionWasDown = false
            Task { @MainActor [onModifierRelease] in
                onModifierRelease()
            }
        } else if optionIsDown {
            optionWasDown = true
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Escape dismisses the switcher without activating anything. Only
        // intercept it while a session is showing so normal Escape keeps
        // working everywhere else; this also recovers a stuck overlay if the
        // Option-release flagsChanged event was ever missed.
        if keyCode == Self.escapeKeyCode {
            guard sessionIsActive else {
                return Unmanaged.passUnretained(event)
            }

            Task { @MainActor [onCancel] in
                onCancel()
            }
            return nil
        }

        let flags = event.flags
        guard flags.contains(.maskAlternate) else {
            return Unmanaged.passUnretained(event)
        }

        let disallowedFlags: CGEventFlags = [.maskCommand, .maskControl]
        guard flags.intersection(disallowedFlags).isEmpty else {
            return Unmanaged.passUnretained(event)
        }

        optionWasDown = true
        let direction: WindowCycleDirection = flags.contains(.maskShift) ? .backward : .forward

        switch keyCode {
        case Self.tabKeyCode:
            Task { @MainActor [onCycleAllApplications, direction] in
                onCycleAllApplications(direction)
            }
            return nil
        case Self.graveKeyCode:
            Task { @MainActor [onCycleCurrentApplication, direction] in
                onCycleCurrentApplication(direction)
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }
}

private let keyboardEventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<KeyboardEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return eventTap.handle(proxy: proxy, type: type, event: event)
}
