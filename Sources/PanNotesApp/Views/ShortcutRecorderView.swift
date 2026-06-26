import MASShortcut
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let defaultsKey: String

    func makeNSView(context: Context) -> MASShortcutView {
        let view = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        view.shortcutValue = storedShortcut()
        view.shortcutValueChange = { sender in
            storeShortcut(sender.shortcutValue)
        }
        return view
    }

    func updateNSView(_ nsView: MASShortcutView, context: Context) {
        nsView.shortcutValue = storedShortcut()
    }

    private func storedShortcut() -> MASShortcut? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return nil
        }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: MASShortcut.self, from: data)
    }

    private func storeShortcut(_ shortcut: MASShortcut?) {
        guard let shortcut else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
            return
        }

        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: shortcut,
            requiringSecureCoding: true
        ) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
