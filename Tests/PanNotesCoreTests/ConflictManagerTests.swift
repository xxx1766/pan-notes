import Foundation
import PanNotesCore

let conflictManagerTests: [TestCase] = [
    TestCase("writeConflictCreatesTimestampedMarkdownCopy", writeConflictCreatesTimestampedMarkdownCopy)
]

private func writeConflictCreatesTimestampedMarkdownCopy() throws {
    let root = try conflictTemporaryDirectory()
    let manager = ConflictManager(rootURL: root)

    let url = try manager.writeConflict(
        dotID: "002",
        externalText: "external version",
        at: Date(timeIntervalSince1970: 120)
    )

    try expect(url.lastPathComponent == "002.conflict-1970-01-01T00-02-00Z.md", "conflict file name")
    let body = try String(contentsOf: url, encoding: .utf8)
    try expect(body == "external version", "conflict body")
}

private func conflictTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesConflictTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
