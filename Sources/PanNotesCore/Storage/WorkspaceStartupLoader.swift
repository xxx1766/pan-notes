import Foundation

public struct WorkspaceStartupResult: Equatable, Sendable {
    public var workspace: Workspace
    public var migratedLocalToICloud: Bool

    public init(workspace: Workspace, migratedLocalToICloud: Bool) {
        self.workspace = workspace
        self.migratedLocalToICloud = migratedLocalToICloud
    }
}

public struct WorkspaceStartupLoader: Sendable {
    private let homeDirectory: URL
    private let savedWorkspacePath: String?
    private let dotCount: Int

    public init(homeDirectory: URL, savedWorkspacePath: String? = nil, dotCount: Int) {
        self.homeDirectory = homeDirectory
        self.savedWorkspacePath = savedWorkspacePath
        self.dotCount = dotCount
    }

    public func load() throws -> WorkspaceStartupResult {
        if let savedWorkspacePath, !savedWorkspacePath.isEmpty {
            let savedURL = URL(filePath: savedWorkspacePath, directoryHint: .isDirectory)
            if isInICloudDrive(savedURL) {
                return try loadICloudWorkspace(legacyICloudURL: savedURL)
            }
            return try loadOrBootstrap(rootURL: savedURL)
        }

        guard FileManager.default.fileExists(atPath: Self.iCloudDriveRootURL(homeDirectory: homeDirectory).path) else {
            return try loadOrBootstrap(rootURL: Self.localWorkspaceURL(homeDirectory: homeDirectory))
        }

        return try loadICloudWorkspace()
    }

    public static func localWorkspaceURL(homeDirectory: URL) -> URL {
        homeDirectory
            .appending(path: "Library/Application Support/PanNotes", directoryHint: .isDirectory)
    }

    public static func iCloudDriveRootURL(homeDirectory: URL) -> URL {
        homeDirectory
            .appending(path: "Library/Mobile Documents/com~apple~CloudDocs", directoryHint: .isDirectory)
    }

    public static func iCloudWorkspaceURL(homeDirectory: URL) -> URL {
        iCloudDriveRootURL(homeDirectory: homeDirectory)
            .appending(path: "PanNotes", directoryHint: .isDirectory)
    }

    private func loadICloudWorkspace(legacyICloudURL: URL? = nil) throws -> WorkspaceStartupResult {
        let iCloudURL = Self.iCloudWorkspaceURL(homeDirectory: homeDirectory)
        let iCloudStore = DotStore(rootURL: iCloudURL)
        if try iCloudStore.hasWorkspaceData() {
            return WorkspaceStartupResult(workspace: try iCloudStore.load(), migratedLocalToICloud: false)
        }

        if let legacyICloudURL, legacyICloudURL.standardizedFileURL != iCloudURL.standardizedFileURL {
            let legacyStore = DotStore(rootURL: legacyICloudURL)
            if try legacyStore.hasWorkspaceData() {
                try iCloudStore.saveWorkspace(try legacyStore.load())
                return WorkspaceStartupResult(workspace: try iCloudStore.load(), migratedLocalToICloud: true)
            }
        }

        let localURL = Self.localWorkspaceURL(homeDirectory: homeDirectory)
        let localStore = DotStore(rootURL: localURL)
        if try localStore.hasWorkspaceData() {
            try iCloudStore.saveWorkspace(try localStore.load())
            return WorkspaceStartupResult(workspace: try iCloudStore.load(), migratedLocalToICloud: true)
        }

        return WorkspaceStartupResult(workspace: try iCloudStore.bootstrap(dotCount: dotCount), migratedLocalToICloud: false)
    }

    private func loadOrBootstrap(rootURL: URL) throws -> WorkspaceStartupResult {
        let store = DotStore(rootURL: rootURL)
        if try store.hasWorkspaceData() {
            return WorkspaceStartupResult(workspace: try store.load(), migratedLocalToICloud: false)
        }

        return WorkspaceStartupResult(workspace: try store.bootstrap(dotCount: dotCount), migratedLocalToICloud: false)
    }

    private func isInICloudDrive(_ url: URL) -> Bool {
        let rootPath = Self.iCloudDriveRootURL(homeDirectory: homeDirectory).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }
}
