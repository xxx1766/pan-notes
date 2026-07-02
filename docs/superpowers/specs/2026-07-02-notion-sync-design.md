# Notion Sync Design

Date: 2026-07-02

## Goal

Add text-only two-way sync between Pan Notes and Notion so the Mac app remains the fast local editor while Notion becomes the practical iPhone editor.

## Non-Goals

- Do not support images, files, embeds, or media upload.
- Do not build an iOS native app path for this feature.
- Do not use Notion AI, Notion Workers, Notion automations, or paid Notion-only features.
- Do not silently discard either side of a same-dot conflict.
- Do not require a custom sync server for the first version.

## Product Shape

Pan Notes adds a Notion Sync section in Settings and a manual sync control in the main panel. The user provides:

- A Notion integration token.
- A Notion parent page URL or page ID.
- An enable/disable toggle.

The token is stored in the macOS Keychain. The parent page ID, per-dot Notion page IDs, and last synced revisions are stored in local Pan Notes metadata. Secrets are not written to the visible notes folder.

## Notion Layout

The selected Notion parent page contains one child page per Pan Notes dot:

```text
Pan Notes
  Dot 1
  Dot 2
  Dot 3
  Dot 4
  Dot 5
  Dot 6
  Dot 7
```

Each dot page is the canonical Notion representation of that dot's body text. The dot page title follows the Pan Notes dot title. The first setup pass creates missing child pages and records their page IDs. If a mapping exists, sync uses the mapped page instead of searching by title.

## Markdown Mapping

The first version maps common text structures:

- Paragraphs.
- Headings 1-3.
- Bullet list items.
- Numbered list items.
- Task list items.
- Block quotes.
- Dividers.
- Fenced code blocks.

Inline bold, italic, strikethrough, links, and inline code remain Markdown text in Notion rich text content for the first version. This keeps round-tripping predictable and avoids losing raw Markdown syntax when Notion edits are pulled back.

Pan Notes manages only the block range between explicit sync marker paragraphs:

```text
<!-- pan-notes:start dot=001 -->
...
<!-- pan-notes:end dot=001 -->
```

Blocks outside that range are left untouched by Pan Notes pushes. Unsupported Notion blocks inside the managed range are converted to plain text markers when possible. Media blocks inside the managed range are ignored with a sync warning because image support is out of scope.

## Sync Semantics

Sync is per dot. Each dot has a local sync state:

- `dotID`
- `notionPageID`
- `lastSyncedLocalHash`
- `lastSyncedNotionHash`
- `lastSyncedAt`

For each dot:

1. Read local Markdown text.
2. Read the mapped Notion page blocks and convert them to Markdown.
3. Compare both texts to the last synced hashes.
4. Apply the merge rule.

Merge rule:

- Local changed, Notion unchanged: push local text to Notion.
- Notion changed, local unchanged: pull Notion text to Pan Notes.
- Both unchanged: update status only.
- Both changed differently: Notion wins, and Pan Notes writes the local text to `conflicts/<dot-id>.conflict-<timestamp>.md` before replacing the local dot text.

This matches the user's phone workflow: Notion edits are treated as intentional when a same-dot conflict exists.

## Notion API Boundary

Pan Notes uses a small Notion client protocol in `PanNotesCore` so sync logic can be unit-tested without network calls. The concrete macOS client uses `URLSession`.

Required API operations:

- Resolve or create a dot child page under a parent page.
- Fetch first-level page block children with pagination.
- Replace a dot page managed range by archiving blocks between the Pan Notes start/end markers and appending converted blocks between fresh markers.
- Update a dot page title when the local dot title changes.

The client must return typed errors for authentication failure, missing access to the parent page, rate limiting, validation failure, and network failure. UI surfaces concise status text and keeps local notes untouched on API failures.

## Settings and Status

Settings adds:

- Enable Notion Sync.
- Token field with Save Token.
- Parent page URL/ID field.
- Setup Pages.
- Sync Now.
- Last sync status.

The main panel adds a sync button near existing tool controls. Sync is manual in the first version. Automatic sync after save is out of scope until manual sync behavior is proven.

## Error Handling

Principles:

- Local text is never overwritten until the replacement has been written or a conflict copy has been created.
- Network and Notion API failures do not modify local dot files.
- Token validation failures keep the previous token until a new one is saved successfully.
- Setup is idempotent: running it again should reuse existing mappings and create only missing pages.

Conflict behavior:

- Same-dot conflict: Notion wins, local text is written to `conflicts/`.
- Missing Notion page for a mapped dot: setup tries to recreate and remap it.
- Missing local dot file: existing `DotStore` behavior recreates the local file; sync then treats local text as empty.

## Testing

Unit tests cover:

- Markdown-to-Notion block conversion for supported structures.
- Notion-block-to-Markdown conversion for supported structures.
- Merge decisions for all local/remote changed combinations.
- Conflict creation when both sides changed.
- Setup idempotency with existing and missing page mappings.
- Keychain/token code through an injectable token store protocol, not the real Keychain.

Integration tests do not call the real Notion API. A fake Notion client drives the sync engine. Manual testing with a real Notion token is a final smoke step only.

## Security

The Notion token is a secret. It must be stored only in Keychain and never in:

- `manifest.json`
- `theme.json`
- `dots/*.md`
- logs
- git-tracked fixtures

The app only needs read, insert, and update content capabilities for the pages the user explicitly connects.
