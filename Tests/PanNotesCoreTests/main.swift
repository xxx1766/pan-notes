let allTests: [TestCase] = manifestTests
    + dotStoreTests
    + backupServiceTests
    + conflictManagerTests
    + notionSyncStateTests
    + notionMarkdownConverterTests
    + notionSyncEngineTests
    + markdownPreviewModelTests
    + textCommandProcessorTests
    + workspaceStartupLoaderTests
    + widgetSnapshotTests

var passed = 0
for test in allTests {
    do {
        try await test.run()
        passed += 1
    } catch {
        print("FAIL \(test.name): \(error)")
        throw error
    }
}

print("PanNotesCoreTests: \(passed) passed")
