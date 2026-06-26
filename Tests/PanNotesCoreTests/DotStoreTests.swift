import Foundation
import PanNotesCore

let dotStoreTests: [TestCase] = [
    TestCase("bootstrapCreatesVisibleLayoutAndDotFiles", bootstrapCreatesVisibleLayoutAndDotFiles),
    TestCase("saveDotWritesOnlyMarkdownBody", saveDotWritesOnlyMarkdownBody),
    TestCase("loadRebuildsManifestWhenManifestIsMissing", loadRebuildsManifestWhenManifestIsMissing)
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

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
