import Foundation

public struct WidgetDotSnapshot: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var displayOrder: Int
    public var themeToken: String
    public var tintHex: String
    public var previewText: String
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        displayOrder: Int,
        themeToken: String,
        tintHex: String,
        previewText: String,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.displayOrder = displayOrder
        self.themeToken = themeToken
        self.tintHex = tintHex
        self.previewText = previewText
        self.updatedAt = updatedAt
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var currentDotID: String
    public var generatedAt: Date
    public var dots: [WidgetDotSnapshot]

    public init(
        schemaVersion: Int,
        currentDotID: String,
        generatedAt: Date,
        dots: [WidgetDotSnapshot]
    ) {
        self.schemaVersion = schemaVersion
        self.currentDotID = currentDotID
        self.generatedAt = generatedAt
        self.dots = dots
    }

    public var selectedDot: WidgetDotSnapshot? {
        dots.first { $0.id == currentDotID } ?? dots.first
    }

    public static func make(
        from workspace: Workspace,
        generatedAt: Date = Date(),
        previewCharacterLimit: Int = 240
    ) -> WidgetSnapshot {
        let tintByToken = Dictionary(uniqueKeysWithValues: workspace.theme.variants.map { variant in
            (variant.name, variant.light.dot)
        })

        let dots = workspace.manifest.dots
            .sorted { lhs, rhs in
                if lhs.displayOrder == rhs.displayOrder {
                    return lhs.id < rhs.id
                }
                return lhs.displayOrder < rhs.displayOrder
            }
            .map { dot in
                WidgetDotSnapshot(
                    id: dot.id,
                    title: dot.title,
                    displayOrder: dot.displayOrder,
                    themeToken: dot.themeToken,
                    tintHex: tintByToken[dot.themeToken] ?? "#242424",
                    previewText: previewText(
                        from: workspace.bodies[dot.id] ?? "",
                        characterLimit: previewCharacterLimit
                    ),
                    updatedAt: dot.updatedAt
                )
            }

        return WidgetSnapshot(
            schemaVersion: 1,
            currentDotID: workspace.manifest.currentDotID,
            generatedAt: generatedAt,
            dots: dots
        )
    }

    private static func previewText(from body: String, characterLimit: Int) -> String {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard characterLimit > 0, normalized.count > characterLimit else {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: characterLimit)
        return String(normalized[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

public enum WidgetSnapshotStore {
    public static let fileName = "widget-snapshot.json"

    public static func snapshotURL(in containerURL: URL) -> URL {
        containerURL.appending(path: fileName)
    }

    public static func save(_ snapshot: WidgetSnapshot, to url: URL) throws {
        let encoder = DotStore.makeEncoder()
        try AtomicFileWriter().write(try encoder.encode(snapshot), to: url)
    }

    public static func load(from url: URL) throws -> WidgetSnapshot? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let decoder = DotStore.makeDecoder()
        return try decoder.decode(WidgetSnapshot.self, from: Data(contentsOf: url))
    }
}
