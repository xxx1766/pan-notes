let allTests: [TestCase] = manifestTests + dotStoreTests + backupServiceTests + conflictManagerTests

var passed = 0
for test in allTests {
    do {
        try test.run()
        passed += 1
    } catch {
        print("FAIL \(test.name): \(error)")
        throw error
    }
}

print("PanNotesCoreTests: \(passed) passed")
