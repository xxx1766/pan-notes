import AppKit

@MainActor
final class StatusBarController {
    private let statusItem: NSStatusItem
    private let target: StatusBarTarget

    init(currentDotHex: String, action: @escaping @MainActor () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.target = StatusBarTarget(action: action)

        if let button = statusItem.button {
            button.image = PanIcon.statusImage(tintHex: currentDotHex)
            button.action = #selector(StatusBarTarget.performAction(_:))
            button.target = target
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    func updateTint(hex: String) {
        statusItem.button?.image = PanIcon.statusImage(tintHex: hex)
    }
}

@MainActor
private final class StatusBarTarget: NSObject {
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            let item = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item.target = NSApp
            menu.addItem(item)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            action()
        }
    }
}
