import Foundation
import PanNotesCore

let manifestTests: [TestCase] = [
    TestCase("defaultManifestCreatesOrderedDots", defaultManifestCreatesOrderedDots),
    TestCase("defaultManifestDisablesOpenAtLogin", defaultManifestDisablesOpenAtLogin),
    TestCase("appPreferencesDecodeOldManifestWithoutOpenAtLogin", appPreferencesDecodeOldManifestWithoutOpenAtLogin),
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

private func defaultManifestDisablesOpenAtLogin() throws {
    let manifest = Manifest.default(dotCount: 1)

    try expect(!manifest.preferences.openAtLogin, "open at login disabled by default")
}

private func appPreferencesDecodeOldManifestWithoutOpenAtLogin() throws {
    let json = """
    {
      "hideDockIcon": true,
      "closeOnFocusLoss": true,
      "backupRetentionCount": 100,
      "autosaveDebounceMilliseconds": 500,
      "backupIntervalMinutes": 60
    }
    """

    let preferences = try DotStore.makeDecoder().decode(AppPreferences.self, from: Data(json.utf8))

    try expect(!preferences.openAtLogin, "old preferences default open at login to false")
}

private func defaultThemeHasLightAndDarkTokens() throws {
    let theme = Theme.defaultTheme

    try expect(theme.variants.count == 8, "theme variant count")
    try expect(theme.variants.first { $0.name == "yellow" }?.light.dot != nil, "yellow light dot")
    try expect(theme.variants.first { $0.name == "yellow" }?.dark.background != nil, "yellow dark background")
}
