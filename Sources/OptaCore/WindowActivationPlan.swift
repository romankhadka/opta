public enum WindowActivationStep: Equatable, Sendable {
    case raiseWindow
    case focusWindow
    case activateApplication
}

public enum WindowActivationPlan {
    // Order matters. Application activation raises whichever window the target
    // application already had in front, so the selected window has to reach the
    // top of its own application first; otherwise a sibling window rides along
    // and lands above the windows of other applications. There is deliberately
    // no "make the application frontmost" step: setting AXFrontmost raises the
    // whole application window group and produces exactly that bug, while
    // activating the running application moves only its front window.
    public static let steps: [WindowActivationStep] = [
        .raiseWindow,
        .focusWindow,
        .activateApplication,
        .focusWindow
    ]
}
