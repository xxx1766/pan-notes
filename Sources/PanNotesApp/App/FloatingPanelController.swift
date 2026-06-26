import AppKit
import PanNotesCore
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: NSPanel

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping @MainActor (Dot) -> Void) {
        let rootView = RootView(workspace: workspace, store: store, onSelectedDotChanged: onSelectedDotChanged)
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pan Notes"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: rootView)
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
