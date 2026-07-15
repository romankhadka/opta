import AppKit
import OptaCore
import SwiftUI

@MainActor
final class SwitcherOverlayController {
    private typealias WindowInteraction = (UInt32) -> Void

    private let previewProvider = WindowPreviewProvider()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SwitcherOverlayView>?
    private var currentSession: WindowCycleSession?
    private var refreshedWindowIDs: [UInt32] = []
    private var previewRefreshTask: Task<Void, Never>?
    private var previewCacheExpirationTask: Task<Void, Never>?
    private var hoverSelectionGate: HoverSelectionGate?
    private var onHoverWindow: WindowInteraction = { _ in }
    private var onClickWindow: WindowInteraction = { _ in }

    func show(
        session: WindowCycleSession,
        onHoverWindow: @escaping (UInt32) -> Void,
        onClickWindow: @escaping (UInt32) -> Void
    ) {
        previewCacheExpirationTask?.cancel()
        previewCacheExpirationTask = nil
        if currentSession == nil {
            hoverSelectionGate = HoverSelectionGate(initialPointerLocation: NSEvent.mouseLocation)
        }
        self.onHoverWindow = onHoverWindow
        self.onClickWindow = onClickWindow
        currentSession = session
        render(session: session)

        // Only (re)capture when the window set changes, i.e. a new session is
        // starting. Advancing the selection within a session reuses the
        // freshly captured previews instead of restarting capture each press.
        let windowIDs = session.windows.map(\.id)
        if windowIDs != refreshedWindowIDs {
            refreshedWindowIDs = windowIDs
            refreshPreviews(for: session.windows)
        }

        panel?.orderFrontRegardless()
    }

    func update(session: WindowCycleSession) {
        currentSession = session
        render(session: session)
    }

    func hide() {
        currentSession = nil
        hoverSelectionGate = nil
        refreshedWindowIDs = []
        previewRefreshTask?.cancel()
        previewRefreshTask = nil
        previewProvider.cancelPendingRefreshes()
        schedulePreviewCacheExpiration()
        panel?.orderOut(nil)
    }

    private func schedulePreviewCacheExpiration() {
        previewCacheExpirationTask?.cancel()
        previewCacheExpirationTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }

            guard !Task.isCancelled, let self else {
                return
            }

            previewProvider.invalidate()
            previewCacheExpirationTask = nil
        }
    }

    private func render(session: WindowCycleSession) {
        let measurement = PerformanceMetrics.begin("OverlayRender")
        defer { PerformanceMetrics.end(measurement) }

        let items = session.windows.map { window in
            SwitcherDisplayItem(
                window: window,
                preview: previewProvider.preview(for: window),
                icon: previewProvider.icon(for: window)
            )
        }
        let selectedWindowID = session.selectedWindow?.id
        let overlayView = SwitcherOverlayView(
            items: items,
            selectedWindowID: selectedWindowID,
            onHoverWindow: { [weak self] windowID in
                self?.handleHover(windowID: windowID)
            },
            onClickWindow: onClickWindow
        )

        if let hostingView {
            hostingView.rootView = overlayView
        } else {
            let hostingView = NSHostingView(rootView: overlayView)
            self.hostingView = hostingView
            makePanel(contentView: hostingView)
        }

        positionPanel(itemCount: items.count)
    }

    private func handleHover(windowID: UInt32) {
        guard windowID != currentSession?.selectedWindow?.id else {
            return
        }
        guard hoverSelectionGate?.shouldSelect(at: NSEvent.mouseLocation) == true else {
            return
        }

        onHoverWindow(windowID)
    }

    private func makePanel(contentView: NSView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1068, height: 198),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = false
        panel.isOpaque = false
        panel.level = .statusBar
        panel.contentView = contentView

        self.panel = panel
    }

    private func refreshPreviews(for windows: [WindowSnapshot]) {
        previewRefreshTask?.cancel()
        previewRefreshTask = Task { @MainActor [weak self, windows] in
            guard let self else {
                return
            }

            let didUpdate = await previewProvider.refreshPreviews(for: windows)
            guard didUpdate, !Task.isCancelled, let currentSession else {
                return
            }

            render(session: currentSession)
        }
    }

    private func positionPanel(itemCount: Int) {
        guard let panel else {
            return
        }

        let columnCount = SwitcherLayout.columnCount(for: itemCount)
        let rowCount = Int(ceil(Double(max(itemCount, 1)) / Double(SwitcherLayout.maxColumns)))
        let width = SwitcherLayout.panelPadding * 2 +
            CGFloat(columnCount) * SwitcherLayout.tileWidth +
            CGFloat(max(columnCount - 1, 0)) * SwitcherLayout.tileSpacing
        let height = SwitcherLayout.panelPadding * 2 +
            CGFloat(rowCount) * SwitcherLayout.tileHeight +
            CGFloat(max(rowCount - 1, 0)) * SwitcherLayout.tileSpacing

        let screen = screenContainingMouse() ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2
        )

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }
}

private enum SwitcherLayout {
    static let tileWidth: CGFloat = 160
    static let tileHeight: CGFloat = 148
    static let tileSpacing: CGFloat = 12
    static let panelPadding: CGFloat = 24
    static let cornerRadius: CGFloat = 16
    static let maxColumns = 6

    static func columnCount(for itemCount: Int) -> Int {
        min(max(itemCount, 1), maxColumns)
    }
}

private enum SwitcherVisualStyle {
    static let containerEdgeOpacity = 0.12
    static let containerShadowOpacity = 0.28
    static let containerShadowRadius: CGFloat = 20
    static let containerShadowYOffset: CGFloat = 10
    static let selectedFillOpacity = 0.10
    static let selectedEdgeOpacity = 0.30
    static let selectedEdgeLineWidth: CGFloat = 1
    static let selectedScale: CGFloat = 1.012
    static let selectionAnimationDuration = 0.11
    static let titleFontSize: CGFloat = 12.5
    static let titleOpacity = 0.96
    static let applicationFontSize: CGFloat = 10.5
    static let applicationNameOpacity = 0.50
    static let applicationIconSize: CGFloat = 20
}

private struct SwitcherDisplayItem: Identifiable {
    let window: WindowSnapshot
    let preview: NSImage?
    let icon: NSImage?

    var id: UInt32 {
        window.id
    }
}

private struct SwitcherOverlayView: View {
    let items: [SwitcherDisplayItem]
    let selectedWindowID: UInt32?
    let onHoverWindow: (UInt32) -> Void
    let onClickWindow: (UInt32) -> Void

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.fixed(SwitcherLayout.tileWidth), spacing: SwitcherLayout.tileSpacing, alignment: .top),
            count: SwitcherLayout.columnCount(for: items.count)
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(SwitcherVisualStyle.containerEdgeOpacity),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(SwitcherVisualStyle.containerShadowOpacity),
                    radius: SwitcherVisualStyle.containerShadowRadius,
                    y: SwitcherVisualStyle.containerShadowYOffset
                )

            LazyVGrid(columns: columns, alignment: .center, spacing: SwitcherLayout.tileSpacing) {
                ForEach(items) { item in
                    SwitcherTileView(
                        item: item,
                        isSelected: item.id == selectedWindowID,
                        onHoverWindow: onHoverWindow,
                        onClickWindow: onClickWindow
                    )
                    .id(item.id)
                }
            }
            .padding(SwitcherLayout.panelPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }
}

private struct SwitcherTileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: SwitcherDisplayItem
    let isSelected: Bool
    let onHoverWindow: (UInt32) -> Void
    let onClickWindow: (UInt32) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
                .frame(width: 138, height: 86)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous))

            HStack(spacing: 7) {
                icon
                    .frame(
                        width: SwitcherVisualStyle.applicationIconSize,
                        height: SwitcherVisualStyle.applicationIconSize
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.window.displayTitle)
                        .font(
                            .system(
                                size: SwitcherVisualStyle.titleFontSize,
                                weight: .semibold,
                                design: .default
                            )
                        )
                        .lineLimit(1)
                        .foregroundStyle(Color.white.opacity(SwitcherVisualStyle.titleOpacity))

                    Text(item.window.applicationName)
                        .font(
                            .system(
                                size: SwitcherVisualStyle.applicationFontSize,
                                weight: .regular,
                                design: .default
                            )
                        )
                        .lineLimit(1)
                        .foregroundStyle(
                            Color.white.opacity(SwitcherVisualStyle.applicationNameOpacity)
                        )
                }
            }
        }
        .padding(10)
        .frame(width: SwitcherLayout.tileWidth, height: SwitcherLayout.tileHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
                .fill(
                    isSelected
                        ? Color.white.opacity(SwitcherVisualStyle.selectedFillOpacity)
                        : Color.clear
                )
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(SwitcherVisualStyle.selectedEdgeOpacity),
                        lineWidth: SwitcherVisualStyle.selectedEdgeLineWidth
                    )
            }
        }
        .scaleEffect(isSelected && !reduceMotion ? SwitcherVisualStyle.selectedScale : 1)
        .contentShape(RoundedRectangle(cornerRadius: SwitcherLayout.cornerRadius, style: .continuous))
        .onContinuousHover { phase in
            guard case .active = phase else {
                return
            }

            onHoverWindow(item.id)
        }
        .onTapGesture {
            onClickWindow(item.id)
        }
        .animation(
            reduceMotion ? nil : .snappy(
                duration: SwitcherVisualStyle.selectionAnimationDuration
            ),
            value: isSelected
        )
    }

    @ViewBuilder
    private var preview: some View {
        if let preview = item.preview {
            Image(nsImage: preview)
                .resizable()
                .scaledToFill()
        } else if let icon = item.icon {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.10, blue: 0.11),
                        Color(red: 0.18, green: 0.20, blue: 0.20),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.12),
                    Color(red: 0.20, green: 0.22, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.18))
        }
    }
}
