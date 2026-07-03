import ApplicationServices
import CoreGraphics

// The CoreGraphics window id of an accessibility element. The public
// "AXWindowNumber" attribute is unsupported by many apps (Chrome, Electron, …),
// so this private but long-stable function is the only reliable way to map an
// accessibility window back to the window snapshot it represents.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func accessibilityWindowNumber(for window: AXUIElement) -> UInt32? {
    var windowID: CGWindowID = 0
    guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else {
        return nil
    }

    return windowID
}
