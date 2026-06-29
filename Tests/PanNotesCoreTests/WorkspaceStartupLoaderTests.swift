import Foundation
import PanNotesCore

let workspaceStartupLoaderTests: [TestCase] = [
    TestCase("startupUsesSavedWorkspacePreference", startupUsesSavedWorkspacePreference),
    TestCase("startupNormalizesSavedICloudWorkspacePreference", startupNormalizesSavedICloudWorkspacePreference),
    TestCase("startupMigratesLocalWorkspaceIntoICloudWhenNoPreference", startupMigratesLocalWorkspaceIntoICloudWhenNoPreference),
    TestCase("startupLoadsExistingICloudWorkspaceBeforeLocal", startupLoadsExistingICloudWorkspaceBeforeLocal),
    TestCase("startupFallsBackToLocalWhenICloudDriveUnavailable", startupFallsBackToLocalWhenICloudDriveUnavailable)
]

private func startupUsesSavedWorkspacePreference() throws {
    let home = try temporaryHomeDirectory()
    _ = try makeICloudDriveRoot(in: home)

    let savedRoot = try temporaryHomeDirectory().appending(path: "Manual", directoryHint: .isDirectory)
    let savedWorkspace = try makeWorkspace(at: savedRoot, body: "# Manual")

    let result = try WorkspaceStartupLoader(
        homeDirectory: home,
        savedWorkspacePath: savedRoot.path,
        dotCount: 1
    ).load()

    try expect(result.workspace.rootURL == savedRoot, "saved preference root")
    try expect(result.workspace.bodies["001"] == savedWorkspace.bodies["001"], "saved preference body")
    try expect(result.migratedLocalToICloud == false, "saved preference does not migrate")
}

private func startupNormalizesSavedICloudWorkspacePreference() throws {
    let home = try temporaryHomeDirectory()
    let iCloudDriveRoot = try makeICloudDriveRoot(in: home)
    let legacyRoot = iCloudDriveRoot.appending(path: "LegacyPanNotes", directoryHint: .isDirectory)
    _ = try makeWorkspace(at: legacyRoot, body: "# Legacy Cloud")

    let result = try WorkspaceStartupLoader(
        homeDirectory: home,
        savedWorkspacePath: legacyRoot.path,
        dotCount: 1
    ).load()

    let standardRoot = WorkspaceStartupLoader.iCloudWorkspaceURL(homeDirectory: home)
    try expect(result.workspace.rootURL == standardRoot, "normalized iCloud root")
    try expect(result.workspace.bodies["001"] == "# Legacy Cloud", "normalized iCloud body")
    try expect(FileManager.default.fileExists(atPath: standardRoot.appending(path: "dots/001.md").path), "normalized dot")
}

private func startupMigratesLocalWorkspaceIntoICloudWhenNoPreference() throws {
    let home = try temporaryHomeDirectory()
    _ = try makeICloudDriveRoot(in: home)
    let localRoot = WorkspaceStartupLoader.localWorkspaceURL(homeDirectory: home)
    _ = try makeWorkspace(at: localRoot, body: "# Local")

    let result = try WorkspaceStartupLoader(homeDirectory: home, dotCount: 1).load()
    let iCloudRoot = WorkspaceStartupLoader.iCloudWorkspaceURL(homeDirectory: home)

    try expect(result.workspace.rootURL == iCloudRoot, "migrated iCloud root")
    try expect(result.workspace.bodies["001"] == "# Local", "migrated body")
    try expect(result.migratedLocalToICloud, "migration flag")
    try expect(FileManager.default.fileExists(atPath: iCloudRoot.appending(path: "manifest.json").path), "migrated manifest")
    try expect(FileManager.default.fileExists(atPath: iCloudRoot.appending(path: "dots/001.md").path), "migrated dot")
}

private func startupLoadsExistingICloudWorkspaceBeforeLocal() throws {
    let home = try temporaryHomeDirectory()
    _ = try makeICloudDriveRoot(in: home)
    _ = try makeWorkspace(at: WorkspaceStartupLoader.localWorkspaceURL(homeDirectory: home), body: "# Local")
    _ = try makeWorkspace(at: WorkspaceStartupLoader.iCloudWorkspaceURL(homeDirectory: home), body: "# Cloud")

    let result = try WorkspaceStartupLoader(homeDirectory: home, dotCount: 1).load()

    try expect(result.workspace.rootURL == WorkspaceStartupLoader.iCloudWorkspaceURL(homeDirectory: home), "iCloud root wins")
    try expect(result.workspace.bodies["001"] == "# Cloud", "iCloud body wins")
    try expect(result.migratedLocalToICloud == false, "existing iCloud does not migrate")
}

private func startupFallsBackToLocalWhenICloudDriveUnavailable() throws {
    let home = try temporaryHomeDirectory()
    _ = try makeWorkspace(at: WorkspaceStartupLoader.localWorkspaceURL(homeDirectory: home), body: "# Local")

    let result = try WorkspaceStartupLoader(homeDirectory: home, dotCount: 1).load()

    try expect(result.workspace.rootURL == WorkspaceStartupLoader.localWorkspaceURL(homeDirectory: home), "local fallback root")
    try expect(result.workspace.bodies["001"] == "# Local", "local fallback body")
    try expect(result.migratedLocalToICloud == false, "local fallback does not migrate")
}

private func makeWorkspace(at root: URL, body: String) throws -> Workspace {
    let store = DotStore(rootURL: root)
    let workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: body, in: workspace)
    return try store.load()
}

private func makeICloudDriveRoot(in home: URL) throws -> URL {
    let url = WorkspaceStartupLoader.iCloudDriveRootURL(homeDirectory: home)
    try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true
    )
    return url
}

private func temporaryHomeDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesHome-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
