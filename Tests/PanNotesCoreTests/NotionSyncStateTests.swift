import Foundation
import PanNotesCore

let notionSyncStateTests: [TestCase] = [
    TestCase("notionSyncStateDefaultsWhenMissing", notionSyncStateDefaultsWhenMissing),
    TestCase("notionSyncStateSavesAndLoadsConfiguration", notionSyncStateSavesAndLoadsConfiguration),
    TestCase("notionSyncStateDoesNotPersistToken", notionSyncStateDoesNotPersistToken),
    TestCase("notionSyncConfigurationStatusUpdatePreservesSyncSettings", notionSyncConfigurationStatusUpdatePreservesSyncSettings),
    TestCase("notionSyncErrorsHaveUserFacingDescriptions", notionSyncErrorsHaveUserFacingDescriptions),
    TestCase("notionPageReferenceParsesAppNotionPageURL", notionPageReferenceParsesAppNotionPageURL),
    TestCase("notionSyncStatePreservesParentPageInput", notionSyncStatePreservesParentPageInput),
    TestCase("notionSyncStateLoadsOldConfigurationWithoutParentPageInput", notionSyncStateLoadsOldConfigurationWithoutParentPageInput)
]

private func notionSyncStateDefaultsWhenMissing() throws {
    let root = try notionSyncTemporaryDirectory()
    let store = NotionSyncStateStore(rootURL: root)

    let configuration = try store.load()

    try expect(configuration == .disabled, "missing sync state defaults to disabled")
}

private func notionSyncStateSavesAndLoadsConfiguration() throws {
    let root = try notionSyncTemporaryDirectory()
    let store = NotionSyncStateStore(rootURL: root)
    let date = Date(timeIntervalSince1970: 1_234)
    let configuration = NotionSyncConfiguration(
        isEnabled: true,
        parentPageID: "parent-page",
        dotPages: [
            "001": NotionDotPageState(
                notionPageID: "notion-page",
                lastSyncedLocalHash: "local-hash",
                lastSyncedNotionHash: "notion-hash",
                lastSyncedAt: date
            )
        ],
        lastStatus: "Synced"
    )

    try store.save(configuration)
    let loaded = try store.load()

    try expect(loaded == configuration, "saved sync configuration round trips")
}

private func notionSyncStateDoesNotPersistToken() throws {
    let root = try notionSyncTemporaryDirectory()
    let store = NotionSyncStateStore(rootURL: root)
    let token = "secret_abc123"
    let configuration = NotionSyncConfiguration(
        isEnabled: true,
        parentPageID: "parent-page",
        dotPages: [:],
        lastStatus: "Synced"
    )

    try store.save(configuration)
    let raw = try String(contentsOf: root.appending(path: "notion-sync.json"), encoding: .utf8)

    try expect(!raw.contains("notion-token"), "does not persist token key")
    try expect(!raw.contains(token), "does not persist token-like secret")
}

private func notionSyncConfigurationStatusUpdatePreservesSyncSettings() throws {
    let date = Date(timeIntervalSince1970: 1_234)
    let pageState = NotionDotPageState(
        notionPageID: "notion-page",
        lastSyncedLocalHash: "local-hash",
        lastSyncedNotionHash: "notion-hash",
        lastSyncedAt: date
    )
    let configuration = NotionSyncConfiguration(
        isEnabled: true,
        parentPageID: "parent-page",
        dotPages: ["001": pageState],
        lastStatus: "Old status"
    )

    let updated = configuration.updatingLastStatus("New status")

    try expect(updated.lastStatus == "New status", "updates status shown by settings")
    try expect(updated.isEnabled == configuration.isEnabled, "preserves enabled flag")
    try expect(updated.parentPageID == configuration.parentPageID, "preserves parent page")
    try expect(updated.dotPages == configuration.dotPages, "preserves dot page state")
}

private func notionSyncErrorsHaveUserFacingDescriptions() throws {
    try expect(
        NotionSyncError.disabled.errorDescription == "Run Notion setup before syncing.",
        "disabled sync error tells user what to do"
    )
    try expect(
        NotionSyncError.missingParentPageID.errorDescription == "Enter a Notion parent page URL or ID.",
        "missing parent page error tells user what to do"
    )
}

private func notionPageReferenceParsesAppNotionPageURL() throws {
    let input = "https://app.notion.com/p/PanNotes-3915d21ca07080a48f3ee1dfc10c7baa"

    let reference = try NotionPageReference(input)

    try expect(reference.rawValue == input, "keeps pasted Notion URL")
    try expect(reference.pageID == "3915d21ca07080a48f3ee1dfc10c7baa", "extracts 32 character page ID")
}

private func notionSyncStatePreservesParentPageInput() throws {
    let root = try notionSyncTemporaryDirectory()
    let store = NotionSyncStateStore(rootURL: root)
    let input = "https://app.notion.com/p/PanNotes-3915d21ca07080a48f3ee1dfc10c7baa"
    let configuration = NotionSyncConfiguration(
        isEnabled: true,
        parentPageInput: input,
        parentPageID: "3915d21ca07080a48f3ee1dfc10c7baa",
        dotPages: [:],
        lastStatus: "Ready"
    )

    try store.save(configuration)
    let loaded = try store.load()

    try expect(loaded.parentPageInput == input, "saved sync state keeps original parent page input")
    try expect(loaded.parentPageID == configuration.parentPageID, "saved sync state keeps parsed parent page ID")
}

private func notionSyncStateLoadsOldConfigurationWithoutParentPageInput() throws {
    let root = try notionSyncTemporaryDirectory()
    let json = """
    {
      "isEnabled" : true,
      "parentPageID" : "3915d21ca07080a48f3ee1dfc10c7baa",
      "dotPages" : {},
      "lastStatus" : "Ready"
    }
    """
    try json.write(to: root.appending(path: "notion-sync.json"), atomically: true, encoding: .utf8)

    let loaded = try NotionSyncStateStore(rootURL: root).load()

    try expect(loaded.parentPageInput == loaded.parentPageID, "old sync state uses parent page ID as input fallback")
}

private func notionSyncTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesNotionSyncStateTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
