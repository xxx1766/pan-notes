# Notion Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build text-only two-way Notion sync for Pan Notes with Notion winning same-dot conflicts and local conflict copies preserved.

**Architecture:** Add testable Notion sync primitives to `PanNotesCore`, keep the real Notion HTTP client and Keychain token store in the macOS app target, then wire manual Setup/Sync controls into Settings and the panel toolbar. Sync state lives in `notion-sync.json`; secrets live only in Keychain.

**Tech Stack:** Swift 6, SwiftUI, Foundation `URLSession`, macOS Security framework, existing executable test harness.

## Global Constraints

- Text only; no images, files, embeds, or media upload.
- No iOS native install path for this feature.
- No Notion AI, Notion Workers, Notion automations, or paid Notion-only features.
- Same-dot conflicts are resolved by Notion winning; Pan Notes writes the local text to `conflicts/`.
- Notion tokens must never be written to `manifest.json`, `theme.json`, `dots/*.md`, logs, fixtures, or git-tracked configuration.
- Do not touch existing Xcode signing changes in `PanNotes.xcodeproj/project.pbxproj` or `PanNotes.xcodeproj/xcuserdata/`.

---

### Task 1: Sync State Storage

**Files:**
- Create: `Sources/PanNotesCore/Sync/NotionSyncState.swift`
- Create: `Tests/PanNotesCoreTests/NotionSyncStateTests.swift`
- Modify: `Tests/PanNotesCoreTests/main.swift`

**Interfaces:**
- Produces: `NotionSyncConfiguration`, `NotionDotPageState`, `NotionSyncStateStore`, and `NotionContentHash.hash(_:)`.
- Consumes: `AtomicFileWriter`.

- [ ] **Step 1: Write failing tests**

Add tests that save/load `notion-sync.json`, return defaults when missing, and prove the token is not part of the stored JSON.

- [ ] **Step 2: Run red test**

Run: `swift run PanNotesCoreTests`

Expected: compile failure because `NotionSyncStateStore` is undefined.

- [ ] **Step 3: Implement state storage**

Implement Codable state with:

```swift
public struct NotionSyncConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var parentPageID: String
    public var dotPages: [String: NotionDotPageState]
    public var lastStatus: String
}

public struct NotionDotPageState: Codable, Equatable, Sendable {
    public var notionPageID: String
    public var lastSyncedLocalHash: String
    public var lastSyncedNotionHash: String
    public var lastSyncedAt: Date?
}
```

- [ ] **Step 4: Run green test**

Run: `swift run PanNotesCoreTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit message: `Add Notion sync state storage`.

### Task 2: Markdown and Notion Block Conversion

**Files:**
- Create: `Sources/PanNotesCore/Sync/NotionBlocks.swift`
- Create: `Sources/PanNotesCore/Sync/NotionMarkdownConverter.swift`
- Create: `Tests/PanNotesCoreTests/NotionMarkdownConverterTests.swift`
- Modify: `Tests/PanNotesCoreTests/main.swift`

**Interfaces:**
- Produces: `NotionBlock`, `NotionBlockKind`, `NotionMarkdownConverter.blocks(from:dotID:)`, `NotionMarkdownConverter.markdown(from:)`, and marker helpers.
- Consumes: no network or storage.

- [ ] **Step 1: Write failing converter tests**

Cover headings, paragraphs, bullet lists, numbered lists, task lists, quotes, dividers, fenced code blocks, marker insertion, marker extraction, and outside-marker preservation decisions.

- [ ] **Step 2: Run red test**

Run: `swift run PanNotesCoreTests`

Expected: compile failure because `NotionMarkdownConverter` is undefined.

- [ ] **Step 3: Implement converter**

Use a deterministic line-oriented parser for first-version Markdown. Preserve unsupported inline Markdown syntax as literal text.

- [ ] **Step 4: Run green test**

Run: `swift run PanNotesCoreTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit message: `Add Notion markdown converter`.

### Task 3: Sync Engine and Conflict Rules

**Files:**
- Create: `Sources/PanNotesCore/Sync/NotionSyncEngine.swift`
- Create: `Tests/PanNotesCoreTests/NotionSyncEngineTests.swift`
- Modify: `Tests/PanNotesCoreTests/main.swift`

**Interfaces:**
- Consumes: Task 1 state storage, Task 2 converter, `DotStore`, `ConflictManager`.
- Produces: `NotionClient` protocol, `NotionSyncEngine.setup(workspace:)`, and `NotionSyncEngine.sync(workspace:)`.

- [ ] **Step 1: Write failing engine tests**

Use a fake Notion client. Cover local-only push, Notion-only pull, unchanged no-op, both-changed conflict with Notion winning, and setup idempotency.

- [ ] **Step 2: Run red test**

Run: `swift run PanNotesCoreTests`

Expected: compile failure because `NotionSyncEngine` is undefined.

- [ ] **Step 3: Implement engine**

Read local bodies, fetch remote blocks, compare hashes, write local dot files only after successful remote reads, and create conflict files before overwriting local text on both-changed conflicts.

- [ ] **Step 4: Run green test**

Run: `swift run PanNotesCoreTests`

Expected: all tests pass.

- [ ] **Step 5: Commit**

Commit message: `Add Notion sync engine`.

### Task 4: Real Notion Client and Keychain Token Store

**Files:**
- Create: `Sources/PanNotesApp/Sync/NotionAPIClient.swift`
- Create: `Sources/PanNotesApp/Sync/KeychainNotionTokenStore.swift`

**Interfaces:**
- Consumes: `NotionClient`, `NotionBlock`, `NotionBlockKind`.
- Produces: `NotionAPIClient(token:)` and `KeychainNotionTokenStore`.

- [ ] **Step 1: Build against missing implementations**

Run: `swift build`

Expected: still passes before files are referenced.

- [ ] **Step 2: Implement HTTP client**

Implement Notion endpoints for create page, update title, list block children, archive block, and append children. Use `Notion-Version: 2026-03-11`.

- [ ] **Step 3: Implement Keychain token store**

Use service `dev.xuqingru.pannotes.notion` and account `notion-token`. Expose `loadToken()`, `saveToken(_:)`, and `deleteToken()`.

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build passes.

- [ ] **Step 5: Commit**

Commit message: `Add Notion API client`.

### Task 5: Settings and Manual Sync UI

**Files:**
- Modify: `Sources/PanNotesApp/Views/RootView.swift`
- Modify: `Sources/PanNotesApp/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `NotionSyncConfiguration`, `NotionSyncStateStore`, `NotionSyncEngine`, `NotionAPIClient`, `KeychainNotionTokenStore`.
- Produces: visible Settings controls and a panel sync button.

- [ ] **Step 1: Wire RootView state**

Load `NotionSyncConfiguration` from the current workspace root. Reload it when the storage folder changes.

- [ ] **Step 2: Add Settings controls**

Add Enable Notion Sync, token field/save button, parent page ID field, Setup Pages, Sync Now, and status text.

- [ ] **Step 3: Add panel sync button**

Add a sync icon near existing tool controls. It saves the current dot, runs manual sync, updates workspace/body text from disk, and updates status.

- [ ] **Step 4: Build**

Run: `swift build`

Expected: build passes.

- [ ] **Step 5: Commit**

Commit message: `Add Notion sync controls`.

### Task 6: Final Verification and Push

**Files:**
- No new files expected.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: pushed GitHub `main`.

- [ ] **Step 1: Run core tests**

Run: `swift run PanNotesCoreTests`

Expected: all tests pass.

- [ ] **Step 2: Run SwiftPM build**

Run: `swift build`

Expected: build passes.

- [ ] **Step 3: Run formatting and plist checks**

Run: `git diff --check`

Expected: no output.

- [ ] **Step 4: Inspect staged files**

Run: `git status --short --branch`

Expected: only intentional Notion sync files are committed or pending; existing Xcode signing/userdata changes remain unstaged unless the user explicitly asks otherwise.

- [ ] **Step 5: Push**

Run: `git push origin HEAD:main`

Expected: GitHub `main` advances.
