import Foundation

public struct NotionDotPageState: Codable, Equatable, Sendable {
    public var notionPageID: String
    public var lastSyncedLocalHash: String
    public var lastSyncedNotionHash: String
    public var lastSyncedAt: Date?

    public init(
        notionPageID: String,
        lastSyncedLocalHash: String,
        lastSyncedNotionHash: String,
        lastSyncedAt: Date?
    ) {
        self.notionPageID = notionPageID
        self.lastSyncedLocalHash = lastSyncedLocalHash
        self.lastSyncedNotionHash = lastSyncedNotionHash
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct NotionSyncConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var parentPageID: String
    public var dotPages: [String: NotionDotPageState]
    public var lastStatus: String

    public init(
        isEnabled: Bool,
        parentPageID: String,
        dotPages: [String: NotionDotPageState],
        lastStatus: String
    ) {
        self.isEnabled = isEnabled
        self.parentPageID = parentPageID
        self.dotPages = dotPages
        self.lastStatus = lastStatus
    }

    public static let disabled = NotionSyncConfiguration(
        isEnabled: false,
        parentPageID: "",
        dotPages: [:],
        lastStatus: "Notion sync disabled"
    )

    public func updatingLastStatus(_ status: String) -> NotionSyncConfiguration {
        var updated = self
        updated.lastStatus = status
        return updated
    }
}

public final class NotionSyncStateStore {
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

    public func load() throws -> NotionSyncConfiguration {
        let url = stateURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .disabled
        }
        return try decoder.decode(NotionSyncConfiguration.self, from: Data(contentsOf: url))
    }

    public func save(_ configuration: NotionSyncConfiguration) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let data = try encoder.encode(configuration)
        try writer.write(data, to: stateURL)
    }

    private var stateURL: URL {
        rootURL.appending(path: "notion-sync.json")
    }
}

public enum NotionContentHash {
    public static func hash(_ text: String) -> String {
        var value: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value &*= 0x100000001b3
        }
        return String(format: "%016llx", value)
    }
}
