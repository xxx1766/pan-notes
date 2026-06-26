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
