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
    public var isAutoSyncEnabled: Bool
    public var parentPageInput: String
    public var parentPageID: String
    public var dotPages: [String: NotionDotPageState]
    public var lastStatus: String

    public init(
        isEnabled: Bool,
        isAutoSyncEnabled: Bool = false,
        parentPageInput: String? = nil,
        parentPageID: String,
        dotPages: [String: NotionDotPageState],
        lastStatus: String
    ) {
        self.isEnabled = isEnabled
        self.isAutoSyncEnabled = isAutoSyncEnabled
        self.parentPageInput = parentPageInput ?? parentPageID
        self.parentPageID = parentPageID
        self.dotPages = dotPages
        self.lastStatus = lastStatus
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case isAutoSyncEnabled
        case parentPageInput
        case parentPageID
        case dotPages
        case lastStatus
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        isAutoSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoSyncEnabled) ?? false
        parentPageID = try container.decode(String.self, forKey: .parentPageID)
        parentPageInput = try container.decodeIfPresent(String.self, forKey: .parentPageInput) ?? parentPageID
        dotPages = try container.decode([String: NotionDotPageState].self, forKey: .dotPages)
        lastStatus = try container.decode(String.self, forKey: .lastStatus)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isAutoSyncEnabled, forKey: .isAutoSyncEnabled)
        try container.encode(parentPageInput, forKey: .parentPageInput)
        try container.encode(parentPageID, forKey: .parentPageID)
        try container.encode(dotPages, forKey: .dotPages)
        try container.encode(lastStatus, forKey: .lastStatus)
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

public struct NotionPageReference: Equatable, Sendable {
    public var rawValue: String
    public var pageID: String

    public init(_ input: String) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NotionPageReferenceError.empty
        }
        guard let pageID = Self.normalizedPageID(from: trimmed) else {
            throw NotionPageReferenceError.missingPageID
        }
        self.rawValue = trimmed
        self.pageID = pageID
    }

    public static func normalizedPageID(from input: String) -> String? {
        let source = searchableText(from: input)
        if let dashed = lastMatch(
            in: source,
            pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        ) {
            return dashed.replacingOccurrences(of: "-", with: "").lowercased()
        }
        return lastMatch(in: source, pattern: #"[0-9a-fA-F]{32}"#)?.lowercased()
    }

    private static func searchableText(from input: String) -> String {
        guard let components = URLComponents(string: input), components.host != nil else {
            return input
        }
        return [components.path, components.fragment]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private static func lastMatch(in source: String, pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = expression.matches(in: source, range: range).last else {
            return nil
        }
        guard let matchRange = Range(match.range, in: source) else {
            return nil
        }
        return String(source[matchRange])
    }
}

public enum NotionPageReferenceError: Error, LocalizedError {
    case empty
    case missingPageID

    public var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a Notion parent page URL or ID."
        case .missingPageID:
            "Could not find a Notion page ID in that URL."
        }
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
