import Foundation

public enum ViewMode: String, Codable, Equatable, Sendable {
    case edit
    case preview
}

public struct Dot: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayOrder: Int
    public var title: String
    public var themeToken: String
    public var fileName: String
    public var preferredViewMode: ViewMode
    public var updatedAt: Date

    public init(
        id: String,
        displayOrder: Int,
        title: String,
        themeToken: String,
        fileName: String,
        preferredViewMode: ViewMode,
        updatedAt: Date
    ) {
        self.id = id
        self.displayOrder = displayOrder
        self.title = title
        self.themeToken = themeToken
        self.fileName = fileName
        self.preferredViewMode = preferredViewMode
        self.updatedAt = updatedAt
    }
}

public struct MarkdownRules: Codable, Equatable, Sendable {
    public var headings: Bool
    public var emphasis: Bool
    public var lists: Bool
    public var taskLists: Bool
    public var links: Bool
    public var inlineCode: Bool
    public var codeBlocks: Bool
    public var blockQuotes: Bool
    public var tables: Bool
    public var strikethrough: Bool
    public var footnotes: Bool
    public var math: Bool
    public var images: Bool

    public static let defaultEnabled = MarkdownRules(
        headings: true,
        emphasis: true,
        lists: true,
        taskLists: true,
        links: true,
        inlineCode: true,
        codeBlocks: true,
        blockQuotes: true,
        tables: true,
        strikethrough: true,
        footnotes: false,
        math: false,
        images: false
    )
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var hideDockIcon: Bool
    public var closeOnFocusLoss: Bool
    public var backupRetentionCount: Int
    public var autosaveDebounceMilliseconds: Int
    public var backupIntervalMinutes: Int

    public static let defaults = AppPreferences(
        hideDockIcon: true,
        closeOnFocusLoss: true,
        backupRetentionCount: 100,
        autosaveDebounceMilliseconds: 500,
        backupIntervalMinutes: 60
    )
}

public struct Manifest: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var currentDotID: String
    public var dots: [Dot]
    public var markdownRules: MarkdownRules
    public var preferences: AppPreferences

    public static func `default`(dotCount: Int) -> Manifest {
        let count = max(1, dotCount)
        let tokens = ["yellow", "orange", "red", "purple", "blue", "teal", "green", "default"]
        let now = Date(timeIntervalSince1970: 0)
        let dots = (1...count).map { index in
            let id = String(format: "%03d", index)
            return Dot(
                id: id,
                displayOrder: index - 1,
                title: "Dot \(index)",
                themeToken: tokens[(index - 1) % tokens.count],
                fileName: "\(id).md",
                preferredViewMode: .edit,
                updatedAt: now
            )
        }
        return Manifest(
            schemaVersion: 1,
            currentDotID: dots[0].id,
            dots: dots,
            markdownRules: .defaultEnabled,
            preferences: .defaults
        )
    }
}
