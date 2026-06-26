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
