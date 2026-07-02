import Foundation
import PanNotesCore

let notionSyncEngineTests: [TestCase] = [
    TestCase("notionSyncEnginePushesLocalOnlyChanges", notionSyncEnginePushesLocalOnlyChanges),
    TestCase("notionSyncEnginePullsNotionOnlyChanges", notionSyncEnginePullsNotionOnlyChanges),
    TestCase("notionSyncEngineWritesConflictWhenBothSidesChanged", notionSyncEngineWritesConflictWhenBothSidesChanged),
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

    func replaceManagedBlocks(pageID: String, dotID: String, blocks: [NotionBlock]) async throws {
        pageBlocks[pageID] = blocks
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
