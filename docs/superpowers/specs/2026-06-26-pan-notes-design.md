# Pan Notes Design

Date: 2026-06-26

## Goal

Build a macOS-only, local-first notes app inspired by Tot's interaction model: a small set of color-coded text slots, fast menu bar access, minimal chrome, and low-friction editing. The app is for personal use and should keep data visible, portable, and recoverable.

## Non-Goals

- Do not clone Tot's brand, icon, copy, private assets, or private implementation.
- Do not build account-based server sync in the first version.
- Do not support Windows, Linux, iOS, or web in the first version.
- Do not implement collaborative editing.
- Do not make the first version a full knowledge-base app with folders, tags, backlinks, or search-heavy workflows.

## Reference Observations

Local non-invasive inspection of `/Applications/Tot.app` showed:

- Tot is a native macOS app using AppKit, SwiftUI, and Combine.
- It links `MASShortcut.framework`, which suggests a native shortcut implementation.
- It has a URL scheme and Shortcuts/Intents-style integration points.
- It uses thin per-dot metadata: title, rich-text mode, and text-button visibility.
- It keeps color as semantic theme tokens for light and dark appearances.
- It is sandboxed and declares iCloud-related entitlements; no custom sync service was evident from public bundle metadata.

Pan Notes should copy the product principles, not the artifacts: native macOS behavior, thin metadata, color-coded slots, semantic themes, and conservative data handling.

## Product Shape

Pan Notes is a menu bar app. The menu bar item uses the user's `pan.svg` asset as the base icon. Because the SVG is a single path without a fixed fill, the app can tint it using the currently selected dot color.

Clicking the menu bar item opens a compact floating window. The window contains:

- A row of color-coded dots.
- One active editor or preview area.
- Minimal status text for save state, conflicts, or errors.
- A small settings entry point.

The app defaults to hiding the Dock icon, but this is configurable. A global shortcut toggles the floating window.

## Dots

Dots are fixed slots, but the count is configurable. This preserves Tot's low-choice interaction while removing the fixed seven-dot limit.

Each dot has:

- Stable ID.
- Display order.
- Title.
- Theme token.
- Markdown file path.
- Preferred view mode: edit or preview.
- Updated timestamp.

The first version should support dot creation/removal by changing the configured count. Removing a dot must require confirmation and should move the old file to a recoverable location rather than deleting it outright.

## Data Layout

The user chooses a visible iCloud Drive folder. A typical folder layout is:

```text
iCloud Drive/Pan/
  manifest.json
  theme.json
  dots/
    001.md
    002.md
    003.md
  backups/
  conflicts/
```

`dots/*.md` files are the source of truth for body content. They should remain plain Markdown files that can be opened in another editor.

`manifest.json` stores only thin metadata:

- Schema version.
- Dot list and ordering.
- Current dot ID.
- Global Markdown rule settings.
- Window and app preferences.
- Backup retention setting.

`theme.json` stores semantic light/dark color tokens:

- `dot`
- `text`
- `accent`
- `statusText`
- `statusBackground`
- `background`
- `link`

Color values should be Pan Notes' own palette, not copied from Tot.

## Sync and Backups

The first version uses iCloud Drive file syncing indirectly through the visible data folder. Pan Notes itself treats the folder as local files and does not depend on a private cloud API.

Save behavior:

- Edits are autosaved with a short debounce.
- Writes should be atomic: write a temporary file in the same directory, then replace.
- The app watches the data folder for external changes.

Conflict behavior:

- Never silently overwrite body text.
- If an external file change arrives while the app has unsaved local edits, keep the editor state and write the external version to `conflicts/<dot-id>.conflict-<timestamp>.md`.
- Surface a conflict marker in the UI.
- Do not attempt automatic text merges in the first version.

Backups:

- Periodically write JSON snapshots to `backups/`.
- A backup includes manifest, theme, and all dot bodies.
- Restoring a backup is explicit and should create a fresh backup of the current state before replacing files.

## Markdown

The app supports edit and preview modes.

Edit mode is plain text editing. Preview mode renders Markdown without changing the underlying `.md` file.

Markdown support is controlled by global rule toggles:

- `headings`
- `emphasis`
- `lists`
- `taskLists`
- `links`
- `inlineCode`
- `codeBlocks`
- `blockQuotes`
- `tables`
- `strikethrough`

Footnotes, math, and images are not part of the first version. The parser and renderer boundaries should allow adding them later.

The preview renderer should avoid arbitrary raw HTML execution. Prefer a Swift Markdown parsing/rendering path that maps supported Markdown nodes into controlled native views.

## Settings

First-version settings:

- Data folder location.
- Dot count.
- Markdown rule toggles.
- Global shortcut.
- Hide or show Dock icon.
- Close floating window on focus loss.
- Backup retention count.

Settings should stay out of the main editing path.

## Architecture

Recommended implementation: SwiftUI with AppKit integration.

Modules:

- `AppShell`: menu bar item, floating window, Dock visibility, global shortcut, URL scheme.
- `DotStore`: manifest/theme/dot-file load and save.
- `SyncWatcher`: file-system observation and conflict detection.
- `EditorCore`: active dot state, autosave, undo, switching behavior.
- `MarkdownPreview`: rule-aware parsing and rendering.
- `Settings`: preferences and validation.

Use AppKit where system behavior matters: menu bar, floating window, `NSTextView`, shortcut capture, and fine-grained window behavior. Use SwiftUI for composable settings and content views.

## Error Handling

Principles:

- Preserve text over preserving presentation state.
- Show explicit status for write failures, conflicts, and missing files.
- Prefer recoverable files over destructive cleanup.

Cases:

- Missing `manifest.json`: rebuild a minimal manifest from `dots/*.md`.
- Missing dot file: recreate an empty file only after recording the missing path in status.
- Invalid JSON: keep the bad file, write a new valid file only with a timestamped backup.
- Write failure: keep unsaved text in memory and show status.
- Theme parse failure: fall back to built-in theme tokens.

## Testing

Unit-test the non-UI layers:

- Manifest load/save and schema migration.
- Dot count changes and recoverable removal.
- Atomic dot writes.
- File-change conflict detection.
- Backup creation and restore.
- Markdown rule filtering.
- Theme token resolution for light and dark appearances.

Manual smoke tests:

- Launch app.
- Open from menu bar.
- Toggle with global shortcut.
- Switch dots.
- Edit and verify `.md` autosave.
- Toggle preview.
- Modify a dot file externally and verify reload.
- Simulate a conflict and verify conflict copy.
- Change data folder.

## Implementation Defaults

Use these defaults unless implementation testing exposes a concrete problem:

- Project layout: standard Xcode macOS app project with small, separate Swift files per module.
- Markdown parser: Apple's Swift Markdown package.
- Global shortcut: `MASShortcut`.
- Backup cadence: on launch, before restore, and every 60 minutes while running.
- Backup retention default: keep the newest 100 snapshots.
- App Sandbox: disabled for the first personal-use build, so the app can work with a visible user-chosen iCloud Drive folder without security-scoped bookmark complexity.
