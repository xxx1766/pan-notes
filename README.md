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
- Optional storage folder selection, including iCloud Drive or any synced folder.
- DMG packaging for quick local installation.

## Install

Download the latest `PanNotes-0.1.0.dmg` from GitHub Releases, open it, and drag `Pan Notes.app` into `Applications`.

This is an unsigned personal build. On macOS, you may need to right-click the app and choose `Open`, or approve it in `System Settings > Privacy & Security`.

Pan Notes requires macOS 14 or newer.

## Usage

- Click the menu bar icon to open or hide the panel.
- Use the dot strip at the top to switch notes.
- Use the pencil/eye segmented control to switch between edit and preview.
- Use the gear button to choose a storage folder, set a global shortcut, or configure Markdown support.
- Use the `x` button to close the panel while keeping the app running.
- Use the power button or `Quit Pan Notes` to fully quit the app.

## Data

By default, Pan Notes stores data in:

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

To sync notes, choose an iCloud Drive folder, Tencent Cloud Drive folder, or another synced folder in Settings. The notes remain ordinary Markdown files.

## Build From Source

```bash
swift build
swift run PanNotes
swift run PanNotesCoreTests
./scripts/package-dmg.sh
```
