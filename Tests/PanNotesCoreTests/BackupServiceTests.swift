import Foundation
import PanNotesCore

let backupServiceTests: [TestCase] = [
    TestCase("createSnapshotWritesManifestThemeAndBodies", createSnapshotWritesManifestThemeAndBodies)
]

private func createSnapshotWritesManifestThemeAndBodies() throws {
    let root = try backupTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "saved text", in: workspace)
    workspace = try store.load()
    let service = BackupService(rootURL: root)

    let url = try service.createSnapshot(from: workspace, at: Date(timeIntervalSince1970: 60))
    let snapshot = try service.restoreSnapshot(from: url)

    try expect(url.lastPathComponent == "1970-01-01T00-01-00Z.json", "backup file name")
    try expect(snapshot.manifest.dots.map(\.id) == ["001"], "snapshot dot ids")
    try expect(snapshot.bodies["001"] == "saved text", "snapshot body")
    try expect(snapshot.theme.variants.count == Theme.defaultTheme.variants.count, "snapshot theme")
}

private func backupTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesBackupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
