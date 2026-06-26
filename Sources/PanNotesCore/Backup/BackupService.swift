import Foundation

public struct BackupSnapshot: Codable, Equatable, Sendable {
    public var manifest: Manifest
    public var theme: Theme
    public var bodies: [String: String]
    public var createdAt: Date

    public init(manifest: Manifest, theme: Theme, bodies: [String: String], createdAt: Date) {
        self.manifest = manifest
        self.theme = theme
        self.bodies = bodies
        self.createdAt = createdAt
    }
}

public final class BackupService {
    private let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let writer: AtomicFileWriter

    public init(
        rootURL: URL,
        encoder: JSONEncoder = DotStore.makeEncoder(),
        decoder: JSONDecoder = DotStore.makeDecoder(),
        writer: AtomicFileWriter = AtomicFileWriter()
    ) {
        self.rootURL = rootURL
        self.encoder = encoder
        self.decoder = decoder
        self.writer = writer
    }

    public func createSnapshot(from workspace: Workspace, at date: Date = Date()) throws -> URL {
        let snapshot = BackupSnapshot(
            manifest: workspace.manifest,
            theme: workspace.theme,
            bodies: workspace.bodies,
            createdAt: date
        )
        let backupsURL = rootURL.appending(path: "backups")
        try FileManager.default.createDirectory(at: backupsURL, withIntermediateDirectories: true)

        let destination = backupsURL.appending(path: "\(Self.timestamp(for: date)).json")
        try writer.write(try encoder.encode(snapshot), to: destination)
        return destination
    }

    public func restoreSnapshot(from url: URL) throws -> BackupSnapshot {
        try decoder.decode(BackupSnapshot.self, from: Data(contentsOf: url))
    }

    static func timestamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
    }
}
