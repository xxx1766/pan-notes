# Pan Notes MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first runnable macOS Pan Notes MVP: a menu bar notes app with color-coded dots, visible Markdown files, thin metadata, edit/preview modes, autosave, backups, and conservative conflict copies.

**Architecture:** Put all data, theme, backup, conflict, and Markdown-rule behavior in a Swift package library that is covered by `swift run PanNotesCoreTests`. Put the macOS app shell in a separate executable target using AppKit for menu bar/window behavior and SwiftUI for the editor/settings views. Run the app during development with `swift run PanNotes`.

**Tech Stack:** Swift 6-compatible package layout, macOS 14 minimum, AppKit, SwiftUI, a self-contained Swift executable test harness, Apple's Swift Markdown package, MASShortcut through Swift Package Manager.

## Global Constraints

- macOS-only first version.
- Personal-use, local-first app.
- Do not clone Tot's brand, icon, copy, private assets, or private implementation.
- Use the user's `~/Downloads/pan.svg` as the Pan Notes icon source.
- Data lives in a visible user-chosen iCloud Drive folder.
- Body text source of truth is `dots/*.md`.
- `manifest.json` stores thin metadata only.
- `theme.json` stores semantic light/dark tokens.
- Conflict handling must never silently overwrite body text.
- First-version Markdown rules are `headings`, `emphasis`, `lists`, `taskLists`, `links`, `inlineCode`, `codeBlocks`, `blockQuotes`, `tables`, and `strikethrough`.
- Footnotes, math, and images are excluded from the first version.
- Backup cadence is on launch, before restore, and every 60 minutes while running.
- Backup retention default is 100 snapshots.
- First personal-use build runs without App Sandbox.
- Commit messages must not contain AI co-author or generated-by trailers.

---

## File Structure

Create this structure:

```text
Package.swift
.gitignore
Sources/
  PanNotesCore/
    Backup/BackupService.swift
    Markdown/MarkdownPreviewModel.swift
    Models/Manifest.swift
    Models/Theme.swift
    Storage/AtomicFileWriter.swift
    Storage/DotStore.swift
    Sync/ConflictManager.swift
  PanNotesApp/
    App/AppDelegate.swift
    App/FloatingPanelController.swift
    App/PanIcon.swift
    App/ShortcutController.swift
    App/StatusBarController.swift
    App/main.swift
    Resources/pan.svg
    Views/DotStripView.swift
    Views/MarkdownPreviewView.swift
    Views/RootView.swift
    Views/SettingsView.swift
    Views/ShortcutRecorderView.swift
    Views/TextEditorRepresentable.swift
Tests/
  PanNotesCoreTests/
    main.swift
    TestSupport.swift
    BackupServiceTests.swift
    ConflictManagerTests.swift
    DotStoreTests.swift
    ManifestTests.swift
    MarkdownPreviewModelTests.swift
```

Responsibilities:

- `PanNotesCore` owns portable, testable behavior and must not import AppKit or SwiftUI.
- `PanNotesApp` owns macOS presentation, menu bar behavior, shortcut wiring, folder selection, and user interaction.
- `DotStore` is the only module that reads/writes `manifest.json`, `theme.json`, and `dots/*.md`.
- `BackupService` creates and restores JSON snapshots.
- `ConflictManager` writes conflict copies.
- `MarkdownPreviewModel` maps Markdown source and enabled rules into safe render nodes.

External package verification already done:

- MASShortcut documents Swift Package Manager usage at `https://github.com/shpakovski/MASShortcut`.
- Swift Markdown exposes a `Markdown` library product at `https://github.com/swiftlang/swift-markdown`.

Local toolchain note: this machine has CommandLineTools but no full Xcode, `xctest`, or importable `XCTest`. Swift Testing also required manual CLT framework paths and was not discovered reliably by SwiftPM. Use the `PanNotesCoreTests` executable target for deterministic local tests.

---

### Task 1: Swift Package Scaffold and Core Models

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `Sources/PanNotesCore/Models/Manifest.swift`
- Create: `Sources/PanNotesCore/Models/Theme.swift`
- Test: `Tests/PanNotesCoreTests/ManifestTests.swift`
- Test: `Tests/PanNotesCoreTests/TestSupport.swift`
- Test: `Tests/PanNotesCoreTests/main.swift`

**Interfaces:**
- Produces: `Manifest.default(dotCount: Int) -> Manifest`
- Produces: `MarkdownRules.defaultEnabled`
- Produces: `Theme.defaultTheme`
- Produces: `Dot`, `AppPreferences`, `ViewMode`, `ThemeVariant`, `ThemeColorSet`

- [ ] **Step 1: Write the failing model tests**

Create `Tests/PanNotesCoreTests/TestSupport.swift`:

```swift
struct TestCase: Sendable {
    var name: String
    var run: @Sendable () throws -> Void

    init(_ name: String, _ run: @escaping @Sendable () throws -> Void) {
        self.name = name
        self.run = run
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ label: String, file: StaticString = #fileID, line: UInt = #line) throws {
    if !condition() {
        throw TestFailure(label: label, file: String(describing: file), line: line)
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    var label: String
    var file: String
    var line: UInt

    var description: String {
        "\(file):\(line): expectation failed: \(label)"
    }
}
```

Create `Tests/PanNotesCoreTests/ManifestTests.swift`:

```swift
import PanNotesCore

let manifestTests: [TestCase] = [
    TestCase("defaultManifestCreatesOrderedDots", defaultManifestCreatesOrderedDots),
    TestCase("defaultThemeHasLightAndDarkTokens", defaultThemeHasLightAndDarkTokens)
]

private func defaultManifestCreatesOrderedDots() throws {
    let manifest = Manifest.default(dotCount: 3)

    try expect(manifest.schemaVersion == 1, "schemaVersion")
    try expect(manifest.currentDotID == "001", "currentDotID")
    try expect(manifest.dots.map(\.id) == ["001", "002", "003"], "dot ids")
    try expect(manifest.dots.map(\.fileName) == ["001.md", "002.md", "003.md"], "dot file names")
    try expect(manifest.dots.map(\.displayOrder) == [0, 1, 2], "dot display order")
    try expect(manifest.preferences.backupRetentionCount == 100, "backup retention")
    try expect(manifest.markdownRules.tables, "tables enabled")
    try expect(!manifest.markdownRules.footnotes, "footnotes disabled")
}

private func defaultThemeHasLightAndDarkTokens() throws {
    let theme = Theme.defaultTheme

    try expect(theme.variants.count == 8, "theme variant count")
    try expect(theme.variants.first { $0.name == "yellow" }?.light.dot != nil, "yellow light dot")
    try expect(theme.variants.first { $0.name == "yellow" }?.dark.background != nil, "yellow dark background")
}
```

Create `Tests/PanNotesCoreTests/main.swift`:

```swift
let allTests: [TestCase] = manifestTests

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
```

- [ ] **Step 2: Run the failing tests**

Run: `swift run PanNotesCoreTests`

Expected: failure because `Package.swift` and `PanNotesCore` do not exist yet.

- [ ] **Step 3: Create the package and model implementation**

Create `Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanNotes",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PanNotesCore", targets: ["PanNotesCore"]),
        .executable(name: "PanNotesCoreTests", targets: ["PanNotesCoreTests"])
    ],
    targets: [
        .target(
            name: "PanNotesCore",
            path: "Sources/PanNotesCore"
        ),
        .executableTarget(
            name: "PanNotesCoreTests",
            dependencies: ["PanNotesCore"],
            path: "Tests/PanNotesCoreTests"
        )
    ]
)
```

Create `.gitignore`:

```gitignore
.build/
.swiftpm/
DerivedData/
*.xcuserstate
.DS_Store
```

Create `Sources/PanNotesCore/Models/Manifest.swift`:

```swift
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
```

Create `Sources/PanNotesCore/Models/Theme.swift`:

```swift
import Foundation

public struct ThemeColorSet: Codable, Equatable, Sendable {
    public var dot: String
    public var text: String
    public var accent: String
    public var statusText: String
    public var statusBackground: String
    public var background: String
    public var link: String
}

public struct ThemeVariant: Codable, Equatable, Sendable {
    public var name: String
    public var light: ThemeColorSet
    public var dark: ThemeColorSet
}

public struct Theme: Codable, Equatable, Sendable {
    public var variants: [ThemeVariant]

    public static let defaultTheme = Theme(variants: [
        ThemeVariant(name: "default", light: .init(dot: "#242424", text: "#111111", accent: "#333333", statusText: "#333333", statusBackground: "#F2F2F2", background: "#FFFFFF", link: "#1D5FD1"), dark: .init(dot: "#F5F5F5", text: "#F5F5F5", accent: "#E5E5E5", statusText: "#E5E5E5", statusBackground: "#202020", background: "#111111", link: "#8AB4FF")),
        ThemeVariant(name: "yellow", light: .init(dot: "#D8A900", text: "#181818", accent: "#735A00", statusText: "#735A00", statusBackground: "#FFF3C4", background: "#FFFBEA", link: "#8A6500"), dark: .init(dot: "#F4C430", text: "#F7F7F7", accent: "#F0D26A", statusText: "#F0D26A", statusBackground: "#3A3218", background: "#18160D", link: "#F1CA45")),
        ThemeVariant(name: "orange", light: .init(dot: "#DD6B20", text: "#171717", accent: "#874213", statusText: "#874213", statusBackground: "#FBE4D0", background: "#FFF4EA", link: "#B45309"), dark: .init(dot: "#FB923C", text: "#FAFAFA", accent: "#FDBA74", statusText: "#FDBA74", statusBackground: "#3B281A", background: "#1B130D", link: "#FDBA74")),
        ThemeVariant(name: "red", light: .init(dot: "#D13447", text: "#161616", accent: "#8A2632", statusText: "#8A2632", statusBackground: "#F9D7DC", background: "#FFF0F2", link: "#B42335"), dark: .init(dot: "#F87171", text: "#FAFAFA", accent: "#FCA5A5", statusText: "#FCA5A5", statusBackground: "#3A2022", background: "#190F10", link: "#FCA5A5")),
        ThemeVariant(name: "purple", light: .init(dot: "#8B5CF6", text: "#161616", accent: "#5B3AA6", statusText: "#5B3AA6", statusBackground: "#E8DFFC", background: "#F8F4FF", link: "#6D49D8"), dark: .init(dot: "#A78BFA", text: "#FAFAFA", accent: "#C4B5FD", statusText: "#C4B5FD", statusBackground: "#30253F", background: "#17111F", link: "#C4B5FD")),
        ThemeVariant(name: "blue", light: .init(dot: "#2563EB", text: "#151515", accent: "#1E4BA8", statusText: "#1E4BA8", statusBackground: "#D8E4FF", background: "#F0F5FF", link: "#1D4ED8"), dark: .init(dot: "#60A5FA", text: "#FAFAFA", accent: "#93C5FD", statusText: "#93C5FD", statusBackground: "#1F2A3D", background: "#101722", link: "#93C5FD")),
        ThemeVariant(name: "teal", light: .init(dot: "#0F9F9C", text: "#151515", accent: "#0B6765", statusText: "#0B6765", statusBackground: "#D5F2EF", background: "#EEFFFD", link: "#0D7D79"), dark: .init(dot: "#2DD4BF", text: "#FAFAFA", accent: "#99F6E4", statusText: "#99F6E4", statusBackground: "#1A3432", background: "#0E1B1A", link: "#5EEAD4")),
        ThemeVariant(name: "green", light: .init(dot: "#4D9F0C", text: "#151515", accent: "#376E0A", statusText: "#376E0A", statusBackground: "#DFF0CE", background: "#F4FFE9", link: "#3F7F0A"), dark: .init(dot: "#86EFAC", text: "#FAFAFA", accent: "#BBF7D0", statusText: "#BBF7D0", statusBackground: "#203322", background: "#101A11", link: "#BBF7D0"))
    ])
}
```

- [ ] **Step 4: Run tests and commit**

Run: `swift run PanNotesCoreTests`

Expected: output includes `PanNotesCoreTests: 2 passed`.

Run: `swift build`

Expected: pass.

Commit:

```bash
git add Package.swift .gitignore Sources/PanNotesCore/Models Tests/PanNotesCoreTests
git commit -m "Add core manifest and theme models"
```

---

### Task 2: DotStore File Layout, Atomic Writes, and Manifest Recovery

**Files:**
- Create: `Sources/PanNotesCore/Storage/AtomicFileWriter.swift`
- Create: `Sources/PanNotesCore/Storage/DotStore.swift`
- Test: `Tests/PanNotesCoreTests/DotStoreTests.swift`

**Interfaces:**
- Consumes: `Manifest`, `Theme`, `Dot`
- Produces: `Workspace`
- Produces: `DotStore.init(rootURL: URL, encoder: JSONEncoder, decoder: JSONDecoder)`
- Produces: `DotStore.bootstrap(dotCount: Int) throws -> Workspace`
- Produces: `DotStore.load() throws -> Workspace`
- Produces: `DotStore.saveManifest(_ manifest: Manifest) throws`
- Produces: `DotStore.saveDot(id: String, body: String, in workspace: Workspace) throws`
- Produces: `AtomicFileWriter.write(_ data: Data, to url: URL) throws`

- [ ] **Step 1: Write failing storage tests**

Create `Tests/PanNotesCoreTests/DotStoreTests.swift`:

```swift
import Foundation
import PanNotesCore

let dotStoreTests: [TestCase] = [
    TestCase("bootstrapCreatesVisibleLayoutAndDotFiles", bootstrapCreatesVisibleLayoutAndDotFiles),
    TestCase("saveDotWritesOnlyMarkdownBody", saveDotWritesOnlyMarkdownBody),
    TestCase("loadRebuildsManifestWhenManifestIsMissing", loadRebuildsManifestWhenManifestIsMissing)
]

private func bootstrapCreatesVisibleLayoutAndDotFiles() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)

    let workspace = try store.bootstrap(dotCount: 2)

    try expect(workspace.manifest.dots.map(\.id) == ["001", "002"], "workspace dot ids")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "manifest.json").path), "manifest exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "theme.json").path), "theme exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "dots/001.md").path), "001.md exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "dots/002.md").path), "002.md exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "backups").path), "backups exists")
    try expect(FileManager.default.fileExists(atPath: root.appending(path: "conflicts").path), "conflicts exists")
}

private func saveDotWritesOnlyMarkdownBody() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)
    let workspace = try store.bootstrap(dotCount: 1)

    try store.saveDot(id: "001", body: "# Hello", in: workspace)

    let body = try String(contentsOf: root.appending(path: "dots/001.md"), encoding: .utf8)
    try expect(body == "# Hello", "dot body")
}

private func loadRebuildsManifestWhenManifestIsMissing() throws {
    let root = try temporaryDirectory()
    let store = DotStore(rootURL: root)
    _ = try store.bootstrap(dotCount: 2)
    try FileManager.default.removeItem(at: root.appending(path: "manifest.json"))

    let workspace = try store.load()

    try expect(workspace.manifest.dots.map(\.fileName) == ["001.md", "002.md"], "rebuilt dot file names")
    try expect(workspace.bodies["001"] == "", "rebuilt body 001")
    try expect(workspace.bodies["002"] == "", "rebuilt body 002")
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
```

Update `Tests/PanNotesCoreTests/main.swift`:

```swift
let allTests: [TestCase] = manifestTests + dotStoreTests
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run PanNotesCoreTests`

Expected: failure because `DotStore` and `AtomicFileWriter` do not exist.

- [ ] **Step 3: Implement atomic writes and store loading**

Create `Sources/PanNotesCore/Storage/AtomicFileWriter.swift`:

```swift
import Foundation

public struct AtomicFileWriter: Sendable {
    public init() {}

    public func write(_ data: Data, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporaryURL = directory.appending(path: ".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
        try data.write(to: temporaryURL, options: .withoutOverwriting)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: url)
        }
    }
}
```

Create `Sources/PanNotesCore/Storage/DotStore.swift`:

```swift
import Foundation

public struct Workspace: Equatable, Sendable {
    public var rootURL: URL
    public var manifest: Manifest
    public var theme: Theme
    public var bodies: [String: String]
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
        let dotFiles = try FileManager.default.contentsOfDirectory(at: rootURL.appending(path: "dots"), includingPropertiesForKeys: nil)
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
```

- [ ] **Step 4: Run tests and commit**

Run: `swift run PanNotesCoreTests`

Expected: output includes `PanNotesCoreTests: 5 passed`.

Run: `swift build`

Expected: pass.

Commit:

```bash
git add Sources/PanNotesCore/Storage Tests/PanNotesCoreTests docs/superpowers/plans/2026-06-26-pan-notes-mvp.md
git commit -m "Add dot store file layout"
```

---

### Task 3: Backups and Conflict Copies

**Files:**
- Create: `Sources/PanNotesCore/Backup/BackupService.swift`
- Create: `Sources/PanNotesCore/Sync/ConflictManager.swift`
- Test: `Tests/PanNotesCoreTests/BackupServiceTests.swift`
- Test: `Tests/PanNotesCoreTests/ConflictManagerTests.swift`

**Interfaces:**
- Consumes: `Workspace`, `Manifest`, `Theme`
- Produces: `BackupSnapshot`
- Produces: `BackupService.createSnapshot(from workspace: Workspace, at date: Date) throws -> URL`
- Produces: `BackupService.restoreSnapshot(from url: URL) throws -> BackupSnapshot`
- Produces: `ConflictManager.writeConflict(dotID: String, externalText: String, at date: Date) throws -> URL`

- [ ] **Step 1: Write failing backup and conflict tests**

Create `Tests/PanNotesCoreTests/BackupServiceTests.swift`:

```swift
import Foundation
import PanNotesCore

let backupServiceTests: [TestCase] = [
    TestCase("createSnapshotWritesManifestThemeAndBodies", createSnapshotWritesManifestThemeAndBodies)
]

private func createSnapshotWritesManifestThemeAndBodies() throws {
    let root = try backupTemporaryDirectory()
    let store = DotStore(rootURL: root)
    var workspace = try store.bootstrap(dotCount: 1)
    try store.saveDot(id: "001", body: "saved text", in: workspace)
    workspace = try store.load()
    let service = BackupService(rootURL: root)

    let url = try service.createSnapshot(from: workspace, at: Date(timeIntervalSince1970: 60))
    let snapshot = try service.restoreSnapshot(from: url)

    try expect(url.lastPathComponent == "1970-01-01T00-01-00Z.json", "backup file name")
    try expect(snapshot.manifest.dots.map(\.id) == ["001"], "snapshot dot ids")
    try expect(snapshot.bodies["001"] == "saved text", "snapshot body")
    try expect(snapshot.theme.variants.count == Theme.defaultTheme.variants.count, "snapshot theme")
}

private func backupTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesBackupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
```

Create `Tests/PanNotesCoreTests/ConflictManagerTests.swift`:

```swift
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
```

Update `Tests/PanNotesCoreTests/main.swift`:

```swift
let allTests: [TestCase] = manifestTests + dotStoreTests + backupServiceTests + conflictManagerTests
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run PanNotesCoreTests`

Expected: failure because `BackupService` and `ConflictManager` do not exist.

- [ ] **Step 3: Implement backups and conflicts**

Create `Sources/PanNotesCore/Backup/BackupService.swift`:

```swift
import Foundation

public struct BackupSnapshot: Codable, Equatable, Sendable {
    public var manifest: Manifest
    public var theme: Theme
    public var bodies: [String: String]
    public var createdAt: Date
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
```

Create `Sources/PanNotesCore/Sync/ConflictManager.swift`:

```swift
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
```

- [ ] **Step 4: Run tests and commit**

Run: `swift run PanNotesCoreTests`

Expected: output includes `PanNotesCoreTests: 7 passed`.

Run: `swift build`

Expected: pass.

Commit:

```bash
git add Sources/PanNotesCore/Backup Sources/PanNotesCore/Sync Tests/PanNotesCoreTests docs/superpowers/plans/2026-06-26-pan-notes-mvp.md
git commit -m "Add backups and conflict copies"
```

---

### Task 4: Rule-Aware Markdown Preview Model

**Files:**
- Modify: `Package.swift`
- Create: `Sources/PanNotesCore/Markdown/MarkdownPreviewModel.swift`
- Test: `Tests/PanNotesCoreTests/MarkdownPreviewModelTests.swift`

**Interfaces:**
- Consumes: `MarkdownRules`
- Produces: `MarkdownRenderNode`
- Produces: `MarkdownPreviewModel.nodes(from source: String, rules: MarkdownRules) -> [MarkdownRenderNode]`

- [ ] **Step 1: Write failing Markdown rule tests**

Create `Tests/PanNotesCoreTests/MarkdownPreviewModelTests.swift`:

```swift
import PanNotesCore

let markdownPreviewModelTests: [TestCase] = [
    TestCase("disabledHeadingsRenderAsPlainText", disabledHeadingsRenderAsPlainText),
    TestCase("enabledHeadingsRenderAsHeadingNode", enabledHeadingsRenderAsHeadingNode),
    TestCase("disabledTablesRenderAsPlainTextLines", disabledTablesRenderAsPlainTextLines),
    TestCase("enabledTaskListsRenderTaskNodes", enabledTaskListsRenderTaskNodes)
]

private func disabledHeadingsRenderAsPlainText() throws {
    var rules = MarkdownRules.defaultEnabled
    rules.headings = false

    let nodes = MarkdownPreviewModel.nodes(from: "# Title", rules: rules)

    try expect(nodes == [.paragraph("Title")], "disabled headings render paragraph")
}

private func enabledHeadingsRenderAsHeadingNode() throws {
    let nodes = MarkdownPreviewModel.nodes(from: "# Title", rules: .defaultEnabled)

    try expect(nodes == [.heading(level: 1, text: "Title")], "enabled headings render heading")
}

private func disabledTablesRenderAsPlainTextLines() throws {
    var rules = MarkdownRules.defaultEnabled
    rules.tables = false

    let source = """
    | A | B |
    | - | - |
    | 1 | 2 |
    """
    let nodes = MarkdownPreviewModel.nodes(from: source, rules: rules)

    try expect(nodes == [.paragraph("| A | B |\n| - | - |\n| 1 | 2 |")], "disabled tables render paragraph")
}

private func enabledTaskListsRenderTaskNodes() throws {
    let nodes = MarkdownPreviewModel.nodes(from: "- [x] Done\n- [ ] Next", rules: .defaultEnabled)

    try expect(
        nodes == [.taskList([
            TaskListItem(text: "Done", isComplete: true),
            TaskListItem(text: "Next", isComplete: false)
        ])],
        "enabled task lists render task nodes"
    )
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift run PanNotesCoreTests`

Expected: failure because `MarkdownPreviewModel` does not exist.

- [ ] **Step 3: Implement the preview model**

Modify `Package.swift` so `PanNotesCore` depends on Swift Markdown:

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-markdown.git", branch: "main")
],
targets: [
    .target(
        name: "PanNotesCore",
        dependencies: [
            .product(name: "Markdown", package: "swift-markdown")
        ],
        path: "Sources/PanNotesCore"
    ),
    .executableTarget(
        name: "PanNotesCoreTests",
        dependencies: ["PanNotesCore"],
        path: "Tests/PanNotesCoreTests"
    )
]
```

Create `Sources/PanNotesCore/Markdown/MarkdownPreviewModel.swift`:

```swift
import Foundation
import Markdown

public struct TaskListItem: Equatable, Sendable {
    public var text: String
    public var isComplete: Bool

    public init(text: String, isComplete: Bool) {
        self.text = text
        self.isComplete = isComplete
    }
}

public enum MarkdownRenderNode: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bulletList([String])
    case taskList([TaskListItem])
    case codeBlock(language: String?, code: String)
    case blockQuote(String)
    case table(raw: String)
}

public enum MarkdownPreviewModel {
    public static func nodes(from source: String, rules: MarkdownRules) -> [MarkdownRenderNode] {
        if isTable(source), rules.tables {
            return [.table(raw: source.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        if isTable(source), !rules.tables {
            return [.paragraph(source.trimmingCharacters(in: .whitespacesAndNewlines))]
        }
        if let taskItems = parseTaskList(source), rules.taskLists {
            return [.taskList(taskItems)]
        }
        if let heading = parseHeading(source) {
            return rules.headings ? [.heading(level: heading.level, text: heading.text)] : [.paragraph(heading.text)]
        }
        var collector = PlainTextCollector()
        let document = Document(parsing: source)
        collector.visit(document)
        let text = collector.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? [] : [.paragraph(text)]
    }

    private static func parseHeading(_ source: String) -> (level: Int, text: String)? {
        let line = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else {
            return nil
        }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func parseTaskList(_ source: String) -> [TaskListItem]? {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return nil }
        var items: [TaskListItem] = []
        for line in lines {
            let text = String(line)
            if text.hasPrefix("- [x] ") || text.hasPrefix("- [X] ") {
                items.append(TaskListItem(text: String(text.dropFirst(6)), isComplete: true))
            } else if text.hasPrefix("- [ ] ") {
                items.append(TaskListItem(text: String(text.dropFirst(6)), isComplete: false))
            } else {
                return nil
            }
        }
        return items
    }

    private static func isTable(_ source: String) -> Bool {
        let lines = source.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count >= 2 else { return false }
        return lines[0].contains("|") && lines[1].contains("-") && lines[1].contains("|")
    }
}

private struct PlainTextCollector: MarkupWalker {
    var text = ""

    mutating func visitText(_ text: Text) {
        self.text += text.string
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) {
        self.text += "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) {
        self.text += "\n"
    }
}
```

- [ ] **Step 4: Run tests and commit**

Run: `swift run PanNotesCoreTests`

Expected: pass.

Run: `swift build`

Expected: pass.

Commit:

```bash
git add Package.swift Package.resolved Sources/PanNotesCore/Markdown Tests/PanNotesCoreTests docs/superpowers/plans/2026-06-26-pan-notes-mvp.md
git commit -m "Add markdown preview model"
```

---

### Task 5: macOS Menu Bar App Shell and Editor Window

**Files:**
- Modify: `Package.swift`
- Modify: `Package.resolved`
- Create: `Sources/PanNotesApp/App/main.swift`
- Create: `Sources/PanNotesApp/App/AppDelegate.swift`
- Create: `Sources/PanNotesApp/App/StatusBarController.swift`
- Create: `Sources/PanNotesApp/App/PanIcon.swift`
- Create: `Sources/PanNotesApp/App/ShortcutController.swift`
- Create: `Sources/PanNotesApp/App/FloatingPanelController.swift`
- Create: `Sources/PanNotesApp/Views/RootView.swift`
- Create: `Sources/PanNotesApp/Views/DotStripView.swift`
- Create: `Sources/PanNotesApp/Views/TextEditorRepresentable.swift`
- Create: `Sources/PanNotesApp/Views/MarkdownPreviewView.swift`
- Create: `Sources/PanNotesApp/Resources/pan.svg`

**Interfaces:**
- Consumes: `DotStore`, `Workspace`, `MarkdownPreviewModel`
- Produces: runnable command `swift run PanNotes`
- Produces: `AppDelegate.toggleWindow()`
- Produces: `RootView.init(workspace: Workspace, store: DotStore)`

- [ ] **Step 1: Copy the icon asset**

Run:

```bash
mkdir -p Sources/PanNotesApp/Resources
cp /Users/annebrown/Downloads/pan.svg Sources/PanNotesApp/Resources/pan.svg
```

Expected: `Sources/PanNotesApp/Resources/pan.svg` exists and is tracked by git.

- [ ] **Step 2: Add the app entry point**

Modify `Package.swift` so the package exposes the app executable, copies app resources, and depends on MASShortcut:

```swift
.executable(name: "PanNotes", targets: ["PanNotes"])

.package(url: "https://github.com/shpakovski/MASShortcut", branch: "master")

.executableTarget(
    name: "PanNotes",
    dependencies: [
        "PanNotesCore",
        .product(name: "MASShortcut", package: "MASShortcut")
    ],
    path: "Sources/PanNotesApp",
    resources: [
        .copy("Resources")
    ]
)
```

Swift 6 build note: AppKit and SwiftUI controller types in this task should be `@MainActor`. MASShortcut default shortcut seeding should use `MASShortcutBinder.shared().registerDefaultShortcuts(...)`; the current Swift import exposes `MASShortcut(keyCode: Int, modifierFlags: NSEvent.ModifierFlags)` and does not expose `dictionaryRepresentation`.

Create `Sources/PanNotesApp/App/main.swift`:

```swift
import AppKit

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
```

Create `Sources/PanNotesApp/App/AppDelegate.swift`:

```swift
import AppKit
import PanNotesCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var shortcutController: ShortcutController?
    private var panelController: FloatingPanelController?
    private var store: DotStore?
    private var workspace: Workspace?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = defaultWorkspaceURL()
        let store = DotStore(rootURL: root)
        let workspace = (try? store.load()) ?? (try! store.bootstrap(dotCount: 7))
        self.store = store
        self.workspace = workspace
        self.statusBarController = StatusBarController(currentDotHex: dotHex(for: workspace.manifest.dots[0], in: workspace), action: { [weak self] in
            self?.toggleWindow()
        })
        self.panelController = FloatingPanelController(workspace: workspace, store: store) { [weak self] dot in
            self?.statusBarController?.updateTint(hex: self?.dotHex(for: dot, in: workspace) ?? "#D8A900")
        }
        self.shortcutController = ShortcutController(defaultsKey: "PanNotesGlobalShortcut") { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
        panelController?.toggle()
    }

    private func defaultWorkspaceURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/PanNotes", directoryHint: .isDirectory)
    }

    private func dotHex(for dot: Dot, in workspace: Workspace) -> String {
        workspace.theme.variants.first { $0.name == dot.themeToken }?.light.dot ?? "#D8A900"
    }
}
```

Create `Sources/PanNotesApp/App/StatusBarController.swift`:

```swift
import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let target: StatusBarTarget

    init(currentDotHex: String, action: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.target = StatusBarTarget(action: action)
        if let button = statusItem.button {
            button.image = PanIcon.statusImage(tintHex: currentDotHex)
            button.action = #selector(StatusBarTarget.performAction)
            button.target = target
        }
    }

    func updateTint(hex: String) {
        statusItem.button?.image = PanIcon.statusImage(tintHex: hex)
    }
}

private final class StatusBarTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}
```

Create `Sources/PanNotesApp/App/PanIcon.swift`:

```swift
import AppKit

enum PanIcon {
    static func statusImage(tintHex: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        let base = Bundle.module.url(forResource: "pan", withExtension: "svg").flatMap(NSImage.init(contentsOf:))
            ?? NSImage(systemSymbolName: "pencil", accessibilityDescription: "Pan Notes")
        base?.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        NSColor(hex: tintHex).setFill()
        rect.fill(using: .sourceIn)
        image.isTemplate = false
        return image
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let raw = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = Int(raw, radix: 16) ?? 0xD8A900
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
```

Create `Sources/PanNotesApp/App/ShortcutController.swift`:

```swift
import AppKit
import Carbon.HIToolbox
import MASShortcut

final class ShortcutController {
    private let defaultsKey: String

    init(defaultsKey: String, action: @escaping () -> Void) {
        self.defaultsKey = defaultsKey
        seedDefaultShortcutIfNeeded()
        MASShortcutBinder.shared().bindShortcut(withDefaultsKey: defaultsKey, toAction: action)
    }

    private func seedDefaultShortcutIfNeeded() {
        guard UserDefaults.standard.object(forKey: defaultsKey) == nil else {
            return
        }
        let flags = NSEvent.ModifierFlags([.command, .option]).rawValue
        guard let shortcut = MASShortcut(keyCode: UInt(kVK_ANSI_P), modifierFlags: flags) else {
            return
        }
        UserDefaults.standard.set(shortcut.dictionaryRepresentation, forKey: defaultsKey)
    }
}
```

Create `Sources/PanNotesApp/App/FloatingPanelController.swift`:

```swift
import AppKit
import SwiftUI
import PanNotesCore

final class FloatingPanelController {
    private let panel: NSPanel

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping (Dot) -> Void) {
        let rootView = RootView(workspace: workspace, store: store, onSelectedDotChanged: onSelectedDotChanged)
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Pan Notes"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: rootView)
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.center()
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
```

- [ ] **Step 3: Add the root editor and preview views**

Create `Sources/PanNotesApp/Views/RootView.swift`:

```swift
import SwiftUI
import PanNotesCore

struct RootView: View {
    @State private var workspace: Workspace
    @State private var selectedDotID: String
    @State private var bodyText: String
    @State private var viewMode: ViewMode
    @State private var statusText = "Saved"

    private let store: DotStore
    private let onSelectedDotChanged: (Dot) -> Void

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping (Dot) -> Void) {
        self._workspace = State(initialValue: workspace)
        self._selectedDotID = State(initialValue: workspace.manifest.currentDotID)
        self._bodyText = State(initialValue: workspace.bodies[workspace.manifest.currentDotID] ?? "")
        self._viewMode = State(initialValue: workspace.manifest.dots.first?.preferredViewMode ?? .edit)
        self.store = store
        self.onSelectedDotChanged = onSelectedDotChanged
    }

    var body: some View {
        VStack(spacing: 0) {
            DotStripView(dots: workspace.manifest.dots, selectedDotID: selectedDotID) { dot in
                saveCurrentDot()
                selectedDotID = dot.id
                bodyText = workspace.bodies[dot.id] ?? ""
                viewMode = dot.preferredViewMode
                onSelectedDotChanged(dot)
            }
            Divider()
            if viewMode == .edit {
                TextEditorRepresentable(text: $bodyText)
                    .onChange(of: bodyText) { _, _ in
                        saveCurrentDot()
                    }
            } else {
                MarkdownPreviewView(nodes: MarkdownPreviewModel.nodes(from: bodyText, rules: workspace.manifest.markdownRules))
            }
            Divider()
            HStack {
                Picker("", selection: $viewMode) {
                    Text("Edit").tag(ViewMode.edit)
                    Text("Preview").tag(ViewMode.preview)
                }
                .pickerStyle(.segmented)
                Spacer()
                Text(statusText).foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 420, minHeight: 420)
    }

    private func saveCurrentDot() {
        do {
            try store.saveDot(id: selectedDotID, body: bodyText, in: workspace)
            workspace.bodies[selectedDotID] = bodyText
            statusText = "Saved"
        } catch {
            statusText = "Save failed"
        }
    }
}
```

Create `Sources/PanNotesApp/Views/DotStripView.swift`:

```swift
import SwiftUI
import PanNotesCore

struct DotStripView: View {
    let dots: [Dot]
    let selectedDotID: String
    let onSelect: (Dot) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(dots.sorted { $0.displayOrder < $1.displayOrder }) { dot in
                Button {
                    onSelect(dot)
                } label: {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: selectedDotID == dot.id ? 16 : 12, height: selectedDotID == dot.id ? 16 : 12)
                        .overlay(Circle().stroke(Color.primary.opacity(selectedDotID == dot.id ? 0.45 : 0), lineWidth: 2))
                }
                .buttonStyle(.plain)
                .help(dot.title)
            }
            Spacer()
        }
        .padding(12)
    }
}
```

Implementation note: pass `Theme` into `DotStripView` and render each dot from its semantic theme token instead of using a single accent color.

Create `Sources/PanNotesApp/Views/TextEditorRepresentable.swift`:

```swift
import AppKit
import SwiftUI

struct TextEditorRepresentable: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView, textView.string != text else {
            return
        }
        textView.string = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            self._text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text = textView.string
        }
    }
}
```

Create `Sources/PanNotesApp/Views/MarkdownPreviewView.swift`:

```swift
import SwiftUI
import PanNotesCore

struct MarkdownPreviewView: View {
    let nodes: [MarkdownRenderNode]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    switch node {
                    case let .heading(level, text):
                        Text(text).font(level == 1 ? .title2 : .headline)
                    case let .paragraph(text):
                        Text(text).font(.body)
                    case let .bulletList(items):
                        ForEach(items, id: \.self) { item in Text("• \(item)") }
                    case let .taskList(items):
                        ForEach(items, id: \.text) { item in
                            HStack { Image(systemName: item.isComplete ? "checkmark.square" : "square"); Text(item.text) }
                        }
                    case let .codeBlock(_, code):
                        Text(code).font(.system(.body, design: .monospaced))
                    case let .blockQuote(text):
                        Text(text).italic()
                    case let .table(raw):
                        Text(raw).font(.system(.body, design: .monospaced))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
```

- [ ] **Step 4: Build and smoke-test the app shell**

Run: `swift build`

Expected: build succeeds.

Run: `swift run PanNotesCoreTests`

Expected: output includes `PanNotesCoreTests: 11 passed`.

Run: `swift run PanNotes`

Expected: a menu bar item appears. Clicking it opens a floating Pan Notes window. Switching dots changes the selected dot. Typing text writes to `~/Library/Application Support/PanNotes/dots/001.md`. Preview mode renders headings and task lists.

Stop the running app with `Ctrl-C` from the terminal.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Package.resolved Sources/PanNotesApp docs/superpowers/plans/2026-06-26-pan-notes-mvp.md
git commit -m "Add macOS menu bar app shell"
```

---

### Task 6: Settings View, Folder Selection, and Final Verification

**Files:**
- Create: `Sources/PanNotesApp/Views/SettingsView.swift`
- Create: `Sources/PanNotesApp/Views/ShortcutRecorderView.swift`
- Modify: `Sources/PanNotesApp/Views/RootView.swift`
- Modify: `Sources/PanNotesApp/App/AppDelegate.swift`
- Modify: `Sources/PanNotesApp/App/StatusBarController.swift`

**Interfaces:**
- Consumes: `Manifest`, `DotStore`, `Workspace`
- Produces: `SettingsView`
- Produces: UI for Markdown rule toggles and data folder selection

- [ ] **Step 1: Add settings UI**

Create `Sources/PanNotesApp/Views/SettingsView.swift`:

```swift
import SwiftUI
import PanNotesCore

struct SettingsView: View {
    @Binding var workspace: Workspace
    let onChooseFolder: () -> Void
    let onSaveManifest: (Manifest) -> Void

    var body: some View {
        Form {
            Section("Storage") {
                Text(workspace.rootURL.path)
                    .font(.caption)
                    .textSelection(.enabled)
                Button("Choose Folder", action: onChooseFolder)
            }
            Section("Shortcut") {
                ShortcutRecorderView(defaultsKey: "PanNotesGlobalShortcut")
                    .frame(width: 220, height: 24)
            }
            Section("Markdown") {
                Toggle("Headings", isOn: binding(\.headings))
                Toggle("Emphasis", isOn: binding(\.emphasis))
                Toggle("Lists", isOn: binding(\.lists))
                Toggle("Task Lists", isOn: binding(\.taskLists))
                Toggle("Links", isOn: binding(\.links))
                Toggle("Inline Code", isOn: binding(\.inlineCode))
                Toggle("Code Blocks", isOn: binding(\.codeBlocks))
                Toggle("Block Quotes", isOn: binding(\.blockQuotes))
                Toggle("Tables", isOn: binding(\.tables))
                Toggle("Strikethrough", isOn: binding(\.strikethrough))
            }
            Section("Window") {
                Toggle("Hide Dock Icon", isOn: preferencesBinding(\.hideDockIcon))
                Toggle("Close on Focus Loss", isOn: preferencesBinding(\.closeOnFocusLoss))
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func binding(_ keyPath: WritableKeyPath<MarkdownRules, Bool>) -> Binding<Bool> {
        Binding(
            get: { workspace.manifest.markdownRules[keyPath: keyPath] },
            set: { value in
                workspace.manifest.markdownRules[keyPath: keyPath] = value
                onSaveManifest(workspace.manifest)
            }
        )
    }

    private func preferencesBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { workspace.manifest.preferences[keyPath: keyPath] },
            set: { value in
                workspace.manifest.preferences[keyPath: keyPath] = value
                onSaveManifest(workspace.manifest)
            }
        )
    }
}
```

Create `Sources/PanNotesApp/Views/ShortcutRecorderView.swift`:

```swift
import SwiftUI
import MASShortcut

struct ShortcutRecorderView: NSViewRepresentable {
    let defaultsKey: String

    func makeNSView(context: Context) -> MASShortcutView {
        let view = MASShortcutView(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        view.associatedUserDefaultsKey = defaultsKey
        return view
    }

    func updateNSView(_ nsView: MASShortcutView, context: Context) {
        if nsView.associatedUserDefaultsKey != defaultsKey {
            nsView.associatedUserDefaultsKey = defaultsKey
        }
    }
}
```

- [ ] **Step 2: Wire settings into RootView**

Modify `Sources/PanNotesApp/Views/RootView.swift` so the status row contains a settings button and sheet:

Add the AppKit import above the SwiftUI import:

```swift
import AppKit
import SwiftUI
```

```swift
@State private var showingSettings = false
```

Add this button to the status `HStack` before `Spacer()`:

```swift
Button {
    showingSettings = true
} label: {
    Image(systemName: "gearshape")
}
.buttonStyle(.plain)
.help("Settings")
```

Add this modifier to the top-level `VStack`:

```swift
.sheet(isPresented: $showingSettings) {
    SettingsView(
        workspace: $workspace,
        onChooseFolder: chooseFolder,
        onSaveManifest: { manifest in
            do {
                try store.saveManifest(manifest)
                statusText = "Settings saved"
            } catch {
                statusText = "Settings save failed"
            }
        }
    )
}
```

Add this helper inside `RootView`:

```swift
private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK, let url = panel.url {
        statusText = "Folder selected: \(url.lastPathComponent)"
    }
}
```

- [ ] **Step 3: Add status bar quit menu**

Modify `Sources/PanNotesApp/App/StatusBarController.swift` so right-click opens a quit menu while left-click still toggles the window:

```swift
button.action = #selector(StatusBarTarget.performAction(_:))
button.sendAction(on: [.leftMouseUp, .rightMouseUp])
```

Replace `StatusBarTarget` with:

```swift
private final class StatusBarTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
        } else {
            action()
        }
    }
}
```

- [ ] **Step 4: Run full verification**

Run: `swift test`

Expected: all tests pass.

Run: `swift build`

Expected: build succeeds.

Run: `swift run PanNotes`

Manual expected results:

- Menu bar item appears.
- Window opens from the menu bar item.
- Text entered in edit mode is saved to `~/Library/Application Support/PanNotes/dots/001.md`.
- Preview mode shows a heading for `# Test`.
- Settings opens from the gear button.
- Turning off `Headings` makes `# Test` preview as plain text after returning to preview.
- App quits cleanly.

- [ ] **Step 5: Commit**

```bash
git add Sources/PanNotesApp
git commit -m "Add settings and final app wiring"
```

---

## Plan Self-Review

Spec coverage:

- Native macOS menu bar app: Task 5.
- `pan.svg` icon resource: Task 5.
- Current dot icon tint: Task 5.
- Global shortcut and shortcut recorder: Tasks 5 and 6.
- Fixed configurable dots: Tasks 1, 2, 6.
- Visible file data layout: Task 2.
- Thin manifest metadata: Tasks 1, 2.
- Semantic theme tokens: Task 1.
- Conservative conflict copies: Task 3.
- Backup snapshots: Task 3.
- Edit/preview modes: Tasks 4, 5.
- Markdown rule toggles: Tasks 4, 6.
- Settings: Task 6.
- Non-UI tests: Tasks 1 through 4.
- Manual smoke tests: Tasks 5 and 6.

Known implementation limit in this MVP plan:

- The first runnable target is a SwiftPM-launched development app, not a signed `.app` bundle. This keeps the first implementation testable from the command line. App bundling can be a follow-up plan after the menu bar workflow and storage behavior are verified.
