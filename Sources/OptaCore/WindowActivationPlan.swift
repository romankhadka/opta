/// The window activation steps a platform backend has to perform.
///
/// The protocol deliberately offers no "make the application frontmost" step:
/// setting AXFrontmost raises the whole application window group, which is the
/// bug `WindowActivationPlan` exists to prevent. `bringWindowToFront` is
/// different: it names one window, and the window server fronts only that
/// window with its process.
public protocol WindowActivationPerforming {
    /// Makes the selected window key and brings its process to the front in one
    /// window server request. Returns false when that path is unavailable.
    func bringWindowToFront() -> Bool
    func raiseWindow()
    func focusWindow()
    func activateApplication()
}

public enum WindowActivationPlan {
    /// Brings the selected window to the front of every other window.
    ///
    /// Application activation is asynchronous, and when it lands the
    /// application re-raises its own last key window. Some applications, such
    /// as Chrome, ignore accessibility focus writes while inactive, so the
    /// public path can bring forward a sibling window, even on another display.
    /// The window server path names the selected window up front and avoids
    /// that race.
    public static func activate(using performer: some WindowActivationPerforming) {
        if performer.bringWindowToFront() {
            performer.raiseWindow()
            return
        }

        // Fallback order matters. Application activation raises whichever
        // window the target application already had in front, so the selected
        // window has to reach the top of its own application first; otherwise
        // a sibling window rides along and lands above the windows of other
        // applications.
        performer.raiseWindow()
        performer.focusWindow()
        performer.activateApplication()
        performer.focusWindow()
    }
}
