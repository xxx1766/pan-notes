import Foundation
import PanNotesCore

let dotStoreTests: [TestCase] = [
    TestCase("bootstrapCreatesVisibleLayoutAndDotFiles", bootstrapCreatesVisibleLayoutAndDotFiles),
    TestCase("saveDotWritesOnlyMarkdownBody", saveDotWritesOnlyMarkdownBody),
    TestCase("loadRebuildsManifestWhenManifestIsMissing", loadRebuildsManifestWhenManifestIsMissing),
    TestCase("hasWorkspaceDataDetectsExistingNotes", hasWorkspaceDataDetectsExistingNotes),
    TestCase("saveWorkspaceMigratesBodiesToNewRoot", saveWorkspaceMigratesBodiesToNewRoot)
]

private func bootstrapCreatesVisibleLayoutAndDotFiles() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)

    let workspace = try store.bootstrap(dotCount: 2)

    try expect(workspace.manifest.dots.map(\.id) == ["001", "002"], "workspace dot ids")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "manifest.json").path), "manifest exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "theme.json").path), "theme exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "dots/001.md").path), "001.md exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "dots/002.md").path), "002.md exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "backups").path), "backups exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "conflicts").path), "conflicts exists")
}

private func saveDotWritesOnlyMarkdownBody() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)
    let workspace = try store.bootstrap(dotCount: 1)

    try store.saveDot(id: "001", body: "# Hello", in: workspace)

    let body = try String(contentsOf: root.appending(path: "dots/001.md"), encoding: .utf8)
    try expect(body == "# Hello", "dot body")
}

private func loadRebuildsManifestWhenManifestIsMissing() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)
    _ = try store.bootstrap(dotCount: 2)
    try FileManager.default.removeItem(at: root.appending(path: "manifest.json"))

    let workspace = try store.load()

    try expect(workspace.manifest.dots.map(\.fileName) == ["001.md", "002.md"], "rebuilt dot file names")
    try expect(workspace.bodies["001"] == "", "rebuilt body 001")
    try expect(workspace.bodies["002"] == "", "rebuilt body 002")
}

private func hasWorkspaceDataDetectsExistingNotes() throws {
    let emptyRoot = try temporaryDirectory()
    let emptyStore = DotStore(rootURL: emptyRoot)
    let emptyHasWorkspaceData = try emptyStore.hasWorkspaceData()

    try expect(emptyHasWorkspaceData == false, "empty folder has no workspace data")

    let root = try temporaryDirectory()
    let dotsURL = root.appending(path: "dots")
    try FileManager.default.createDirectory(at: dotsURL, withIntermediateDirectories: true)
    try "body".write(to: dotsURL.appending(path: "001.md"), atomically: true, encoding: .utf8)

    let hasWorkspaceData = try DotStore(rootURL: root).hasWorkspaceData()
    try expect(hasWorkspaceData, "dot file counts as workspace data")
}

private func saveWorkspaceMigratesBodiesToNewRoot() throws {
    let sourceRoot = try temporaryDirectory()
    let sourceStore = DotStore(rootURL: sourceRoot)
    var workspace = try sourceStore.bootstrap(dotCount: 2)
    try sourceStore.saveDot(id: "001", body: "# First", in: workspace)
    try sourceStore.saveDot(id: "002", body: "- Second", in: workspace)
    workspace = try sourceStore.load()

    let targetRoot = try temporaryDirectory()
    let targetStore = DotStore(rootURL: targetRoot)
    try targetStore.saveWorkspace(workspace)
    let migrated = try targetStore.load()

    try expect(migrated.rootURL == targetRoot, "migrated root")
    try expect(migrated.manifest.dots.map(\.id) == ["001", "002"], "migrated dot ids")
    try expect(migrated.bodies["001"] == "# First", "migrated first body")
    try expect(migrated.bodies["002"] == "- Second", "migrated second body")
    try expect(FileManager.default.fileExists(atPath: targetRoot.appending(path: "theme.json").path), "migrated theme")
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
