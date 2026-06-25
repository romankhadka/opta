import CoreGraphics

public enum KeyboardEventMask {
    public static var keyboardCaptureEvents: CGEventMask {
        eventMaskBit(.keyDown) | eventMaskBit(.flagsChanged)
    }

    private static func eventMaskBit(_ eventType: CGEventType) -> CGEventMask {
        CGEventMask(1) << eventType.rawValue
    }
}
