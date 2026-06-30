# Pan Notes

Pan Notes is a local-first macOS menu bar notes app for fast plain-text and Markdown notes.

It is built for personal use: seven color-coded dots, visible Markdown files on disk, and a compact panel that opens from the menu bar or a global shortcut.

## Features

- Seven dot-based note slots with matching menu bar colors.
- Plain-text editing with optional Markdown preview.
- Configurable Markdown rendering for headings, emphasis, lists, task lists, links, inline code, code blocks, block quotes, tables, and strikethrough.
- Smart bullets and task lists, including clickable task toggles in preview mode.
- Quick Keys for smart bullets, bullets, dividers, date, and time.
- Automatic indentation helpers plus indent and outdent commands.
- Find, Find and Replace, Find Next, and Find Previous.
- Text size slider in the panel.
- Local file storage with atomic writes, backups, and conflict folders.
- Automatic iCloud Drive storage when available, with optional manual folder selection.
- DMG packaging for quick local installation.

## Install

Download the latest `PanNotes-0.3.1.dmg` from GitHub Releases, open it, and drag `Pan Notes.app` into `Applications`.

This is an ad-hoc signed personal build, not a notarized Developer ID release. On macOS, you may need to right-click the app and choose `Open`, or approve it in `System Settings > Privacy & Security`.

If macOS says the app is damaged after downloading it from GitHub, drag `Pan Notes.app` into `Applications`, then run:

```bash
xattr -dr com.apple.quarantine "/Applications/Pan Notes.app"
```

A warning-free public release requires signing with an Apple Developer ID certificate and notarizing the DMG with Apple.

Pan Notes requires macOS 14 or newer.

## Usage

- Click the menu bar icon to open or hide the panel.
- Use the dot strip at the top to switch notes.
- Use the pencil/eye segmented control to switch between edit and preview.
- Use the gear button to choose a storage folder, set a global shortcut, or configure Markdown support.
- Use the `x` button to close the panel while keeping the app running.
- Use the power button or `Quit Pan Notes` to fully quit the app.

## Data

By default, Pan Notes stores data in iCloud Drive when it is available:

```text
~/Library/Mobile Documents/com~apple~CloudDocs/PanNotes
```

If iCloud Drive is not available, Pan Notes falls back to local storage:

```text
~/Library/Application Support/PanNotes
```

The folder contains:

```text
manifest.json
theme.json
dots/*.md
backups/
conflicts/
```

When Pan Notes first sees iCloud Drive, it uses `iCloud Drive/PanNotes` automatically. If local notes already exist and that iCloud folder is empty, Pan Notes copies the local workspace there and switches to it.

Manual folder selection in Settings overrides the automatic iCloud location. Use it only if you want Tencent Cloud Drive or another synced folder.

Pan Notes does not run its own sync server. The notes remain ordinary Markdown files and sync through the folder provider you choose.

## Build From Source

```bash
swift build
swift run PanNotes
swift run PanNotesCoreTests
./scripts/package-dmg.sh
```
