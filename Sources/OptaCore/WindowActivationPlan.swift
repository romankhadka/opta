/// The window activation steps a platform backend has to perform.
///
/// The protocol deliberately offers no "make the application frontmost" step:
/// setting AXFrontmost raises the whole application window group, which is the
/// bug `WindowActivationPlan` exists to prevent.
public protocol WindowActivationPerforming {
    func raiseWindow()
    func focusWindow()
    func activateApplication()
}

public enum WindowActivationPlan {
    /// Brings the selected window to the front of every other window.
    ///
    /// Order matters. Application activation raises whichever window the target
    /// application already had in front, so the selected window has to reach the
    /// top of its own application first; otherwise a sibling window rides along
    /// and lands above the windows of other applications.
    public static func activate(using performer: some WindowActivationPerforming) {
        performer.raiseWindow()
        performer.focusWindow()
        performer.activateApplication()
        performer.focusWindow()
    }
}
