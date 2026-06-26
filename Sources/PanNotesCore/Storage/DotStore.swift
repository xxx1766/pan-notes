import Foundation

public struct Workspace: Equatable, Sendable {
    public var rootURL: URL
    public var manifest: Manifest
    public var theme: Theme
    public var bodies: [String: String]

    public init(rootURL: URL, manifest: Manifest, theme: Theme, bodies: [String: String]) {
        self.rootURL = rootURL
        self.manifest = manifest
        self.theme = theme
        self.bodies = bodies
    }
}

public final class DotStore {
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

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func bootstrap(dotCount: Int) throws -> Workspace {
        try createDirectories()

        let manifest = Manifest.default(dotCount: dotCount)
        let theme = Theme.defaultTheme
        try saveManifest(manifest)
        try saveTheme(theme)

        for dot in manifest.dots {
            let url = dotURL(fileName: dot.fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try writer.write(Data(), to: url)
            }
        }

        return try load()
    }

    public func load() throws -> Workspace {
        try createDirectories()

        let manifest = try loadManifestOrRebuild()
        let theme = try loadThemeOrDefault()
        var bodies: [String: String] = [:]

        for dot in manifest.dots {
            let url = dotURL(fileName: dot.fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try writer.write(Data(), to: url)
            }
            bodies[dot.id] = try String(contentsOf: url, encoding: .utf8)
        }

        return Workspace(rootURL: rootURL, manifest: manifest, theme: theme, bodies: bodies)
    }

    public func saveManifest(_ manifest: Manifest) throws {
        let data = try encoder.encode(manifest)
        try writer.write(data, to: rootURL.appending(path: "manifest.json"))
    }

    public func saveTheme(_ theme: Theme) throws {
        let data = try encoder.encode(theme)
        try writer.write(data, to: rootURL.appending(path: "theme.json"))
    }

    public func saveDot(id: String, body: String, in workspace: Workspace) throws {
        guard let dot = workspace.manifest.dots.first(where: { $0.id == id }) else {
            throw DotStoreError.unknownDot(id)
        }

        try writer.write(Data(body.utf8), to: dotURL(fileName: dot.fileName))
    }

    private func createDirectories() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootURL.appending(path: "dots"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootURL.appending(path: "backups"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootURL.appending(path: "conflicts"), withIntermediateDirectories: true)
    }

    private func loadManifestOrRebuild() throws -> Manifest {
        let url = rootURL.appending(path: "manifest.json")
        if FileManager.default.fileExists(atPath: url.path) {
            return try decoder.decode(Manifest.self, from: Data(contentsOf: url))
        }

        let dotFiles = try FileManager.default.contentsOfDirectory(
            at: rootURL.appending(path: "dots"),
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "md" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var manifest = Manifest.default(dotCount: max(1, dotFiles.count))
        for (index, file) in dotFiles.enumerated() {
            let id = file.deletingPathExtension().lastPathComponent
            manifest.dots[index].id = id
            manifest.dots[index].fileName = file.lastPathComponent
            manifest.dots[index].title = "Dot \(index + 1)"
            manifest.dots[index].displayOrder = index
        }
        manifest.currentDotID = manifest.dots[0].id

        try saveManifest(manifest)
        return manifest
    }

    private func loadThemeOrDefault() throws -> Theme {
        let url = rootURL.appending(path: "theme.json")
        if FileManager.default.fileExists(atPath: url.path) {
            return try decoder.decode(Theme.self, from: Data(contentsOf: url))
        }

        let theme = Theme.defaultTheme
        try saveTheme(theme)
        return theme
    }

    private func dotURL(fileName: String) -> URL {
        rootURL.appending(path: "dots").appending(path: fileName)
    }
}

public enum DotStoreError: Error, Equatable {
    case unknownDot(String)
}
