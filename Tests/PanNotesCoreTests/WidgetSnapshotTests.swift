import Foundation
import PanNotesCore

let widgetSnapshotTests: [TestCase] = [
    TestCase("widgetSnapshotBuildsOrderedDotPreviews", widgetSnapshotBuildsOrderedDotPreviews),
    TestCase("widgetSnapshotStoreRoundTripsSnapshotJSON", widgetSnapshotStoreRoundTripsSnapshotJSON)
]

private func widgetSnapshotBuildsOrderedDotPreviews() throws {
    var manifest = Manifest.default(dotCount: 3)
    manifest.currentDotID = "002"
    manifest.dots[0].displayOrder = 2
    manifest.dots[1].displayOrder = 0
    manifest.dots[1].themeToken = "blue"
    manifest.dots[2].displayOrder = 1

    let workspace = Workspace(
        rootURL: URL(filePath: "/tmp/pan-notes-widget-test"),
        manifest: manifest,
        theme: .defaultTheme,
        bodies: [
            "001": "  A long yellow note that needs to be shortened for widgets.  ",
            "002": "# Blue current note\n\nSecond line",
            "003": ""
        ]
    )

    let snapshot = WidgetSnapshot.make(
        from: workspace,
        generatedAt: Date(timeIntervalSince1970: 12),
        previewCharacterLimit: 20
    )

    try expect(snapshot.schemaVersion == 1, "schema version")
    try expect(snapshot.currentDotID == "002", "current dot id")
    try expect(snapshot.generatedAt == Date(timeIntervalSince1970: 12), "generated date")
    try expect(snapshot.dots.map(\.id) == ["002", "003", "001"], "ordered ids")
    try expect(snapshot.selectedDot?.id == "002", "selected dot")
    try expect(snapshot.dots[0].previewText == "# Blue current note...", "current preview")
    try expect(snapshot.dots[0].tintHex == "#2563EB", "current tint")
    try expect(snapshot.dots[1].previewText.isEmpty, "empty preview")
}

private func widgetSnapshotStoreRoundTripsSnapshotJSON() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "PanNotesWidgetSnapshotTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    let url = WidgetSnapshotStore.snapshotURL(in: directory)

    let snapshot = WidgetSnapshot(
        schemaVersion: 1,
        currentDotID: "001",
        generatedAt: Date(timeIntervalSince1970: 34),
        dots: [
            WidgetDotSnapshot(
                id: "001",
                title: "Dot 1",
                displayOrder: 0,
                themeToken: "yellow",
                tintHex: "#D8A900",
                previewText: "Hello",
                updatedAt: Date(timeIntervalSince1970: 56)
            )
        ]
    )

    try WidgetSnapshotStore.save(snapshot, to: url)
    let loaded = try WidgetSnapshotStore.load(from: url)

    try expect(loaded == snapshot, "loaded snapshot")
}
