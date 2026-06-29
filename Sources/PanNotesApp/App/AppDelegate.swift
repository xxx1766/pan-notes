import AppKit
import PanNotesCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var shortcutController: ShortcutController?
    private var panelController: FloatingPanelController?
    private var store: DotStore?
    private var workspace: Workspace?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMainMenu()

        let root = defaultWorkspaceURL()
        let store = DotStore(rootURL: root)
        let workspace = loadInitialWorkspace(from: store, rootURL: root)

        self.store = store
        self.workspace = workspace
        self.statusBarController = StatusBarController(
            currentDotHex: dotHex(for: workspace.manifest.dots[0], in: workspace),
            action: { [weak self] in
                self?.toggleWindow()
            }
        )
        self.panelController = FloatingPanelController(workspace: workspace, store: store) { [weak self] dot in
            self?.statusBarController?.updateTint(hex: self?.dotHex(for: dot, in: workspace) ?? "#D8A900")
        }
        self.shortcutController = ShortcutController(defaultsKey: "PanNotesGlobalShortcut") { [weak self] in
            self?.toggleWindow()
        }
        self.panelController?.show()
    }

    func toggleWindow() {
        panelController?.toggle()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "Pan Notes")
        appMenuItem.submenu = appMenu
        let quitItem = NSMenuItem(
            title: "Quit Pan Notes",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        appMenu.addItem(quitItem)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(Self.editMenuItem("Undo", action: Selector(("undo:")), key: "z"))
        editMenu.addItem(Self.editMenuItem("Redo", action: Selector(("redo:")), key: "z", modifiers: [.command, .shift]))
        editMenu.addItem(.separator())
        editMenu.addItem(Self.editMenuItem("Cut", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(Self.editMenuItem("Copy", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(Self.editMenuItem("Paste", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(Self.editMenuItem("Select All", action: #selector(NSText.selectAll(_:)), key: "a"))
        editMenu.addItem(.separator())
        editMenu.addItem(Self.editMenuItem("Toggle Smart Bullet", action: #selector(PanTextView.toggleSmartBullet(_:)), key: "\r", modifiers: [.command]))
        editMenu.addItem(Self.editMenuItem("Indent", action: #selector(PanTextView.indentSelectedLines(_:)), key: "]"))
        editMenu.addItem(Self.editMenuItem("Outdent", action: #selector(PanTextView.outdentSelectedLines(_:)), key: "["))
        editMenu.addItem(.separator())
        editMenu.addItem(Self.textFinderMenuItem("Find", action: .showFindInterface, key: "f"))
        editMenu.addItem(Self.textFinderMenuItem("Find and Replace", action: .showReplaceInterface, key: "f", modifiers: [.command, .option]))
        editMenu.addItem(Self.textFinderMenuItem("Find Next", action: .nextMatch, key: "g"))
        editMenu.addItem(Self.textFinderMenuItem("Find Previous", action: .previousMatch, key: "g", modifiers: [.command, .shift]))

        NSApp.mainMenu = mainMenu
    }

    private static func editMenuItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = nil
        return item
    }

    private static func textFinderMenuItem(
        _ title: String,
        action: NSTextFinder.Action,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = editMenuItem(
            title,
            action: #selector(NSResponder.performTextFinderAction(_:)),
            key: key,
            modifiers: modifiers
        )
        item.tag = action.rawValue
        return item
    }

    private func loadInitialWorkspace(from store: DotStore, rootURL: URL) -> Workspace {
        let manifestURL = rootURL.appending(path: "manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path), let workspace = try? store.load() {
            return workspace
        }
        return try! store.bootstrap(dotCount: 7)
    }

    private func defaultWorkspaceURL() -> URL {
        if let path = UserDefaults.standard.string(forKey: "PanNotesWorkspaceURL"), !path.isEmpty {
            return URL(filePath: path, directoryHint: .isDirectory)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/PanNotes", directoryHint: .isDirectory)
    }

    private func dotHex(for dot: Dot, in workspace: Workspace) -> String {
        workspace.theme.variants.first { $0.name == dot.themeToken }?.light.dot ?? "#D8A900"
    }
}
