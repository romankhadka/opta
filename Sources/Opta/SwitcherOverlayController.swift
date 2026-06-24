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
    private var previewRefreshTask: Task<Void, Never>?
    private var onHoverWindow: WindowInteraction = { _ in }
    private var onClickWindow: WindowInteraction = { _ in }

    func show(
        session: WindowCycleSession,
        onHoverWindow: @escaping (UInt32) -> Void,
        onClickWindow: @escaping (UInt32) -> Void
    ) {
        self.onHoverWindow = onHoverWindow
        self.onClickWindow = onClickWindow
        currentSession = session
        render(session: session)
        refreshPreviews(for: session.windows)
        panel?.orderFrontRegardless()
    }

    func update(session: WindowCycleSession) {
        currentSession = session
        render(session: session)
    }

    func hide() {
        currentSession = nil
        previewRefreshTask?.cancel()
        previewRefreshTask = nil
        panel?.orderOut(nil)
    }

    private func render(session: WindowCycleSession) {
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
            onHoverWindow: onHoverWindow,
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

    private func makePanel(contentView: NSView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1068, height: 198),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = true
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

        let tileWidth: CGFloat = 160
        let tileHeight: CGFloat = 148
        let tileSpacing: CGFloat = 12
        let panelPadding: CGFloat = 24
        let columnCount = min(max(itemCount, 1), 6)
        let rowCount = Int(ceil(Double(max(itemCount, 1)) / 6.0))
        let width = panelPadding * 2 +
            CGFloat(columnCount) * tileWidth +
            CGFloat(max(columnCount - 1, 0)) * tileSpacing
        let height = panelPadding * 2 +
            CGFloat(rowCount) * tileHeight +
            CGFloat(max(rowCount - 1, 0)) * tileSpacing

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
        let columnCount = min(max(items.count, 1), 6)
        return Array(
            repeating: GridItem(.fixed(160), spacing: 12, alignment: .top),
            count: columnCount
        )
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.38), radius: 32, y: 18)

            LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
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
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SwitcherTileView: View {
    let item: SwitcherDisplayItem
    let isSelected: Bool
    let onHoverWindow: (UInt32) -> Void
    let onClickWindow: (UInt32) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
                .frame(width: 138, height: 86)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            HStack(spacing: 7) {
                icon
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.window.displayTitle)
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .lineLimit(1)
                        .foregroundStyle(.white)

                    Text(item.window.applicationName)
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .lineLimit(1)
                        .foregroundStyle(Color.white.opacity(0.62))
                }
            }
        }
        .padding(10)
        .frame(width: 160, height: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(
                    isSelected ? Color(red: 0.62, green: 0.64, blue: 0.66) : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.025 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onHover { isHovering in
            guard isHovering else {
                return
            }

            onHoverWindow(item.id)
        }
        .onTapGesture {
            onClickWindow(item.id)
        }
        .animation(.snappy(duration: 0.12), value: isSelected)
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
