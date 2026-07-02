import Foundation

public protocol NotionClient: Sendable {
    func ensureDotPage(parentPageID: String, dot: Dot, existingPageID: String?) async throws -> String
    func fetchBlocks(pageID: String) async throws -> [NotionBlock]
    func replaceManagedBlocks(pageID: String, dotID: String, blocks: [NotionBlock]) async throws
    func updatePageTitle(pageID: String, title: String) async throws
}

public struct NotionSyncResult: Equatable, Sendable {
    public var configuration: NotionSyncConfiguration
    public var pushedDotIDs: [String]
    public var pulledDotIDs: [String]
    public var conflictedDotIDs: [String]

    public init(
        configuration: NotionSyncConfiguration,
        pushedDotIDs: [String],
        pulledDotIDs: [String],
        conflictedDotIDs: [String]
    ) {
        self.configuration = configuration
        self.pushedDotIDs = pushedDotIDs
        self.pulledDotIDs = pulledDotIDs
        self.conflictedDotIDs = conflictedDotIDs
    }
}

public enum NotionSyncError: Error, Equatable {
    case disabled
    case missingParentPageID
}

public final class NotionSyncEngine {
    private let client: any NotionClient
    private let stateStore: NotionSyncStateStore
    private let dotStore: DotStore
    private let conflictManager: ConflictManager
    private let now: @Sendable () -> Date

    public init(
        client: any NotionClient,
        stateStore: NotionSyncStateStore,
        dotStore: DotStore,
        conflictManager: ConflictManager,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client
        self.stateStore = stateStore
        self.dotStore = dotStore
        self.conflictManager = conflictManager
        self.now = now
    }

    public func setup(workspace: Workspace) async throws -> NotionSyncConfiguration {
        var configuration = try stateStore.load()
        guard !configuration.parentPageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotionSyncError.missingParentPageID
        }

        for dot in workspace.manifest.dots {
            let existingPageID = configuration.dotPages[dot.id]?.notionPageID
            let pageID = try await client.ensureDotPage(
                parentPageID: configuration.parentPageID,
                dot: dot,
                existingPageID: existingPageID
            )
            try await client.updatePageTitle(pageID: pageID, title: dot.title)
            configuration.dotPages[dot.id] = configuration.dotPages[dot.id] ?? .unsynced(pageID: pageID)
            configuration.dotPages[dot.id]?.notionPageID = pageID
        }

        configuration.isEnabled = true
        configuration.lastStatus = "Notion pages ready"
        try stateStore.save(configuration)
        return configuration
    }

    public func sync(workspace: Workspace) async throws -> NotionSyncResult {
        var configuration = try stateStore.load()
        guard configuration.isEnabled else {
            throw NotionSyncError.disabled
        }
        guard !configuration.parentPageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotionSyncError.missingParentPageID
        }

        var pushedDotIDs: [String] = []
        var pulledDotIDs: [String] = []
        var conflictedDotIDs: [String] = []

        for dot in workspace.manifest.dots {
            var pageState = try await pageState(for: dot, in: &configuration)
            let pageID = pageState.notionPageID
            let localText = workspace.bodies[dot.id] ?? ""
            let localHash = NotionContentHash.hash(localText)
            let remoteBlocks = try await client.fetchBlocks(pageID: pageID)
            let remoteManagedBlocks = NotionMarkdownConverter.managedBlocks(in: remoteBlocks, dotID: dot.id)
            let remoteText = NotionMarkdownConverter.markdown(from: remoteManagedBlocks)
            let remoteHash = NotionContentHash.hash(remoteText)

            let localChanged = localHash != pageState.lastSyncedLocalHash
            let remoteChanged = remoteHash != pageState.lastSyncedNotionHash

            if localChanged && remoteChanged && localHash != remoteHash {
                _ = try conflictManager.writeConflict(dotID: dot.id, externalText: localText, at: now())
                try dotStore.saveDot(id: dot.id, body: remoteText, in: workspace)
                pageState = pageState.synced(localHash: remoteHash, notionHash: remoteHash, at: now())
                conflictedDotIDs.append(dot.id)
            } else if localChanged {
                try await client.replaceManagedBlocks(
                    pageID: pageID,
                    dotID: dot.id,
                    blocks: NotionMarkdownConverter.blocks(from: localText, dotID: dot.id)
                )
                pageState = pageState.synced(localHash: localHash, notionHash: localHash, at: now())
                pushedDotIDs.append(dot.id)
            } else if remoteChanged {
                try dotStore.saveDot(id: dot.id, body: remoteText, in: workspace)
                pageState = pageState.synced(localHash: remoteHash, notionHash: remoteHash, at: now())
                pulledDotIDs.append(dot.id)
            } else {
                pageState = pageState.synced(localHash: localHash, notionHash: remoteHash, at: now())
            }

            configuration.dotPages[dot.id] = pageState
        }

        configuration.lastStatus = statusText(
            pushed: pushedDotIDs.count,
            pulled: pulledDotIDs.count,
            conflicted: conflictedDotIDs.count
        )
        try stateStore.save(configuration)
        return NotionSyncResult(
            configuration: configuration,
            pushedDotIDs: pushedDotIDs,
            pulledDotIDs: pulledDotIDs,
            conflictedDotIDs: conflictedDotIDs
        )
    }

    private func pageState(
        for dot: Dot,
        in configuration: inout NotionSyncConfiguration
    ) async throws -> NotionDotPageState {
        if let state = configuration.dotPages[dot.id] {
            return state
        }

        let pageID = try await client.ensureDotPage(
            parentPageID: configuration.parentPageID,
            dot: dot,
            existingPageID: nil
        )
        let state = NotionDotPageState.unsynced(pageID: pageID)
        configuration.dotPages[dot.id] = state
        return state
    }

    private func statusText(pushed: Int, pulled: Int, conflicted: Int) -> String {
        let parts = [
            pushed > 0 ? "\(pushed) pushed" : nil,
            pulled > 0 ? "\(pulled) pulled" : nil,
            conflicted > 0 ? "\(conflicted) conflicts" : nil
        ].compactMap { $0 }

        return parts.isEmpty ? "Notion sync up to date" : "Notion sync: \(parts.joined(separator: ", "))"
    }
}

private extension NotionDotPageState {
    static func unsynced(pageID: String) -> NotionDotPageState {
        let emptyHash = NotionContentHash.hash("")
        return NotionDotPageState(
            notionPageID: pageID,
            lastSyncedLocalHash: emptyHash,
            lastSyncedNotionHash: emptyHash,
            lastSyncedAt: nil
        )
    }

    func synced(localHash: String, notionHash: String, at date: Date) -> NotionDotPageState {
        NotionDotPageState(
            notionPageID: notionPageID,
            lastSyncedLocalHash: localHash,
            lastSyncedNotionHash: notionHash,
            lastSyncedAt: date
        )
    }
}
