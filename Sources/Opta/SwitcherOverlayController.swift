import AppKit
import OptaCore
import SwiftUI

@MainActor
final class SwitcherOverlayController {
    private let previewProvider = WindowPreviewProvider()
    private var panel: NSPanel?
    private var hostingView: NSHostingView<SwitcherOverlayView>?
    private var currentSession: WindowCycleSession?
    private var previewRefreshTask: Task<Void, Never>?

    func show(session: WindowCycleSession) {
        currentSession = session
        render(session: session)
        refreshPreviews(for: session.windows)
        panel?.orderFrontRegardless()
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
        let overlayView = SwitcherOverlayView(items: items, selectedWindowID: selectedWindowID)

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
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 310),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = true
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

        let tileWidth: CGFloat = 184
        let horizontalPadding: CGFloat = 44
        let maxVisibleTiles: CGFloat = 5
        let visibleTiles = min(CGFloat(max(itemCount, 1)), maxVisibleTiles)
        let width = min(980, horizontalPadding * 2 + visibleTiles * tileWidth)
        let height: CGFloat = 310

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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.38), radius: 32, y: 18)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(items) { item in
                            SwitcherTileView(
                                item: item,
                                isSelected: item.id == selectedWindowID
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 26)
                }
                .onChange(of: selectedWindowID) { _, newID in
                    guard let newID else {
                        return
                    }

                    withAnimation(.snappy(duration: 0.14)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SwitcherTileView: View {
    let item: SwitcherDisplayItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            preview
                .frame(width: 152, height: 104)
                .background(Color.black.opacity(0.28))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            HStack(spacing: 8) {
                icon
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
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
        .padding(12)
        .frame(width: 176, height: 206, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isSelected ? Color(red: 0.92, green: 0.78, blue: 0.40) : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.04 : 1.0)
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
                    .frame(width: 52, height: 52)
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
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.18))
        }
    }
}
