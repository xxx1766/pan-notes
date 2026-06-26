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
            button.action = #selector(StatusBarTarget.performAction)
            button.target = target
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

    @objc func performAction() {
        action()
    }
}
