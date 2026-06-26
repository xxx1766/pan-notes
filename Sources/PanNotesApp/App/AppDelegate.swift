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
    }

    func toggleWindow() {
        panelController?.toggle()
    }

    private func loadInitialWorkspace(from store: DotStore, rootURL: URL) -> Workspace {
        let manifestURL = rootURL.appending(path: "manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path), let workspace = try? store.load() {
            return workspace
        }
        return try! store.bootstrap(dotCount: 7)
    }

    private func defaultWorkspaceURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/PanNotes", directoryHint: .isDirectory)
    }

    private func dotHex(for dot: Dot, in workspace: Workspace) -> String {
        workspace.theme.variants.first { $0.name == dot.themeToken }?.light.dot ?? "#D8A900"
    }
}
