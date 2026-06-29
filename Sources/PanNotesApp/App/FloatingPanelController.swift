import AppKit
import PanNotesCore
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping @MainActor (Dot) -> Void) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let rootView = RootView(
            workspace: workspace,
            store: store,
            onSelectedDotChanged: onSelectedDotChanged,
            onClose: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        self.panel = panel
        panel.title = "Pan Notes"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.transient, .moveToActiveSpace]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = NSHostingView(rootView: rootView)
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
