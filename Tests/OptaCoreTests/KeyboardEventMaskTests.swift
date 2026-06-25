import CoreGraphics
import Testing

@testable import OptaCore

@Suite("Keyboard event mask")
struct KeyboardEventMaskTests {
    @Test("keyboard capture mask includes only real keyboard event types")
    func keyboardCaptureMaskIncludesOnlyRealKeyboardEventTypes() {
        let expectedMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        #expect(KeyboardEventMask.keyboardCaptureEvents == expectedMask)
    }
}
