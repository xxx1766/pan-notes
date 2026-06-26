import AppKit
import Carbon.HIToolbox
import MASShortcut

@MainActor
final class ShortcutController {
    private let defaultsKey: String

    init(defaultsKey: String, action: @escaping @MainActor () -> Void) {
        self.defaultsKey = defaultsKey
        seedDefaultShortcutIfNeeded()
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: defaultsKey) {
            Task { @MainActor in
                action()
            }
        }
    }

    private func seedDefaultShortcutIfNeeded() {
        guard UserDefaults.standard.object(forKey: defaultsKey) == nil else {
            return
        }

        let flags = NSEvent.ModifierFlags([.command, .option])
        let shortcut = MASShortcut(keyCode: Int(kVK_ANSI_P), modifierFlags: flags)
        MASShortcutBinder.shared().registerDefaultShortcuts([defaultsKey: shortcut])
    }
}
