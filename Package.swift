// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanNotes",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PanNotesCore", targets: ["PanNotesCore"]),
        .executable(name: "PanNotes", targets: ["PanNotes"]),
        .executable(name: "PanNotesCoreTests", targets: ["PanNotesCoreTests"])
    ],
    dependencies: [
        .package(url: "https://github.com/shpakovski/MASShortcut", branch: "master"),
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
            name: "PanNotes",
            dependencies: [
                "PanNotesCore",
                .product(name: "MASShortcut", package: "MASShortcut")
            ],
            path: "Sources/PanNotesApp",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "PanNotesCoreTests",
            dependencies: ["PanNotesCore"],
            path: "Tests/PanNotesCoreTests"
        )
    ]
)
