import Foundation
import PanNotesCore

let notionSyncEngineTests: [TestCase] = [
    TestCase("notionSyncEnginePushesLocalOnlyChanges", notionSyncEnginePushesLocalOnlyChanges),
    TestCase("notionSyncEngineDeletesManagedBlocksBeforeAppendingPush", notionSyncEngineDeletesManagedBlocksBeforeAppendingPush),
    TestCase("notionSyncEnginePullsNotionOnlyChanges", notionSyncEnginePullsNotionOnlyChanges),
    TestCase("notionSyncEngineWritesConflictWhenBothSidesChanged", notionSyncEngineWritesConflictWhenBothSidesChanged),
    TestCase("notionSyncEnginePreservesLocalConflictWhenRequested", notionSyncEnginePreservesLocalConflictWhenRequested),
    TestCase("notionSyncEngineSetupReusesExistingPageMappings", notionSyncEngineSetupReusesExistingPageMappings)
]

private func notionSyncEnginePushesLocalOnlyChanges() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "# Local", in: workspace)
    workspace = try store.load()
    try makeConfiguredState(root: root, dotID: "001", pageID: "page-001", local: "", notion: "")
    let client = FakeNotionClient(pageBlocks: [
        "page-001": NotionMarkdownConverter.blocks(from: "", dotID: "001")
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let result = try await engine.sync(workspace: workspace)
    let pushedMarkdown = NotionMarkdownConverter.markdown(from: client.pageBlocks["page-001"] ?? [])

    try expect(result.pushedDotIDs == ["001"], "local-only change is pushed")
    try expect(pushedMarkdown == "# Local", "remote page receives local markdown")
}

private func notionSyncEngineDeletesManagedBlocksBeforeAppendingPush() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "New local", in: workspace)
    workspace = try store.load()
    try makeConfiguredState(root: root, dotID: "001", pageID: "page-001", local: "Old remote", notion: "Old remote")
    let client = FakeNotionClient(pageBlocks: [
        "page-001": [
            .paragraph("Outside before", id: "outside-before"),
            .paragraph("<!-- pan-notes:start dot=001 -->", id: "start"),
            .paragraph("Old remote", id: "old"),
            .paragraph("<!-- pan-notes:end dot=001 -->", id: "end"),
            .paragraph("Outside after", id: "outside-after")
        ]
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let result = try await engine.sync(workspace: workspace)
    let remainingIDs = client.pageBlocks["page-001"]?.compactMap(\.id) ?? []
    let pushedMarkdown = NotionMarkdownConverter.markdown(from: client.pageBlocks["page-001"] ?? [])

    try expect(result.pushedDotIDs == ["001"], "local-only change is pushed")
    try expect(client.deletedBlockIDs == ["start", "old", "end"], "old managed blocks are deleted with the block delete endpoint")
    try expect(remainingIDs.contains("outside-before"), "outside block before managed range is preserved")
    try expect(remainingIDs.contains("outside-after"), "outside block after managed range is preserved")
    try expect(pushedMarkdown.contains("New local"), "new managed content is appended")
}

private func notionSyncEnginePullsNotionOnlyChanges() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    let workspace = try store.bootstrap(dotCount: 1)
    try makeConfiguredState(root: root, dotID: "001", pageID: "page-001", local: "", notion: "")
    let client = FakeNotionClient(pageBlocks: [
        "page-001": NotionMarkdownConverter.blocks(from: "Remote", dotID: "001")
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let result = try await engine.sync(workspace: workspace)
    let loaded = try store.load()

    try expect(result.pulledDotIDs == ["001"], "notion-only change is pulled")
    try expect(loaded.bodies["001"] == "Remote", "local dot receives remote markdown")
}

private func notionSyncEngineWritesConflictWhenBothSidesChanged() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "Local", in: workspace)
    workspace = try store.load()
    try makeConfiguredState(root: root, dotID: "001", pageID: "page-001", local: "Base", notion: "Base")
    let client = FakeNotionClient(pageBlocks: [
        "page-001": NotionMarkdownConverter.blocks(from: "Remote", dotID: "001")
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let result = try await engine.sync(workspace: workspace)
    let loaded = try store.load()
    let conflicts = try FileManager.default.contentsOfDirectory(
        at: root.appending(path: "conflicts"),
        includingPropertiesForKeys: nil
    )
    let conflictText = try String(contentsOf: conflicts[0], encoding: .utf8)

    try expect(result.conflictedDotIDs == ["001"], "both-changed conflict is reported")
    try expect(loaded.bodies["001"] == "Remote", "Notion wins same-dot conflict")
    try expect(conflictText == "Local", "local conflict copy is preserved")
}

private func notionSyncEnginePreservesLocalConflictWhenRequested() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "Local", in: workspace)
    workspace = try store.load()
    try makeConfiguredState(root: root, dotID: "001", pageID: "page-001", local: "Base", notion: "Base")
    let client = FakeNotionClient(pageBlocks: [
        "page-001": NotionMarkdownConverter.blocks(from: "Remote", dotID: "001")
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let result = try await engine.sync(workspace: workspace, conflictResolution: .preserveLocal)
    let loaded = try store.load()
    let configuration = try NotionSyncStateStore(rootURL: root).load()
    let conflicts = try FileManager.default.contentsOfDirectory(
        at: root.appending(path: "conflicts"),
        includingPropertiesForKeys: nil
    )
    let conflictText = try String(contentsOf: conflicts[0], encoding: .utf8)

    try expect(result.conflictedDotIDs == ["001"], "both-changed conflict is reported")
    try expect(loaded.bodies["001"] == "Local", "local dot remains unchanged")
    try expect(conflictText == "Remote", "remote conflict copy is preserved")
    try expect(
        configuration.dotPages["001"]?.lastSyncedLocalHash == NotionContentHash.hash("Base"),
        "preserved conflict keeps previous local sync hash"
    )
    try expect(
        configuration.dotPages["001"]?.lastSyncedNotionHash == NotionContentHash.hash("Base"),
        "preserved conflict keeps previous Notion sync hash"
    )
}

private func notionSyncEngineSetupReusesExistingPageMappings() async throws {
    let root = try notionSyncEngineTemporaryDirectory()
    let store = DotStore(rootURL: root)
    let workspace = try store.bootstrap(dotCount: 1)
    try makeConfiguredState(root: root, dotID: "001", pageID: "existing-page", local: "", notion: "")
    let client = FakeNotionClient(pageBlocks: [
        "existing-page": NotionMarkdownConverter.blocks(from: "", dotID: "001")
    ])
    let engine = NotionSyncEngine(
        client: client,
        stateStore: NotionSyncStateStore(rootURL: root),
        dotStore: store,
        conflictManager: ConflictManager(rootURL: root),
        now: { Date(timeIntervalSince1970: 2_000) }
    )

    let configuration = try await engine.setup(workspace: workspace)

    try expect(configuration.dotPages["001"]?.notionPageID == "existing-page", "existing page mapping is reused")
    try expect(client.createdPageIDs.isEmpty, "setup does not create page when mapping exists")
}

private final class FakeNotionClient: NotionClient, @unchecked Sendable {
    var pageBlocks: [String: [NotionBlock]]
    var createdPageIDs: [String] = []
    var deletedBlockIDs: [String] = []

    init(pageBlocks: [String: [NotionBlock]]) {
        self.pageBlocks = pageBlocks
    }

    func ensureDotPage(parentPageID: String, dot: Dot, existingPageID: String?) async throws -> String {
        if let existingPageID {
            if pageBlocks[existingPageID] == nil {
                pageBlocks[existingPageID] = NotionMarkdownConverter.blocks(from: "", dotID: dot.id)
            }
            return existingPageID
        }

        let pageID = "created-\(dot.id)"
        createdPageIDs.append(pageID)
        pageBlocks[pageID] = NotionMarkdownConverter.blocks(from: "", dotID: dot.id)
        return pageID
    }

    func fetchBlocks(pageID: String) async throws -> [NotionBlock] {
        pageBlocks[pageID] ?? []
    }

    func appendBlocks(pageID: String, blocks: [NotionBlock]) async throws {
        pageBlocks[pageID, default: []].append(contentsOf: blocks)
    }

    func deleteBlock(blockID: String) async throws {
        deletedBlockIDs.append(blockID)
        for pageID in pageBlocks.keys {
            pageBlocks[pageID]?.removeAll { $0.id == blockID }
        }
    }

    func updatePageTitle(pageID: String, title: String) async throws {}
}

private func makeConfiguredState(
    root: URL,
    dotID: String,
    pageID: String,
    local: String,
    notion: String
) throws {
    try NotionSyncStateStore(rootURL: root).save(NotionSyncConfiguration(
        isEnabled: true,
        parentPageID: "parent-page",
        dotPages: [
            dotID: NotionDotPageState(
                notionPageID: pageID,
                lastSyncedLocalHash: NotionContentHash.hash(local),
                lastSyncedNotionHash: NotionContentHash.hash(notion),
                lastSyncedAt: Date(timeIntervalSince1970: 1_000)
            )
        ],
        lastStatus: "Ready"
    ))
}

private func notionSyncEngineTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesNotionSyncEngineTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
