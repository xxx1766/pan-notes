import Foundation

public final class ConflictManager {
    private let rootURL: URL
    private let writer: AtomicFileWriter

    public init(rootURL: URL, writer: AtomicFileWriter = AtomicFileWriter()) {
        self.rootURL = rootURL
        self.writer = writer
    }

    public func writeConflict(dotID: String, externalText: String, at date: Date = Date()) throws -> URL {
        let conflictsURL = rootURL.appending(path: "conflicts")
        try FileManager.default.createDirectory(at: conflictsURL, withIntermediateDirectories: true)

        let destination = conflictsURL.appending(path: "\(dotID).conflict-\(BackupService.timestamp(for: date)).md")
        try writer.write(Data(externalText.utf8), to: destination)
        return destination
    }
}
