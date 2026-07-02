import AppKit
import PanNotesCore
import SwiftUI

struct RootView: View {
    @State private var workspace: Workspace
    @State private var selectedDotID: String
    @State private var bodyText: String
    @State private var viewMode: ViewMode
    @State private var statusText = "Saved"
    @State private var showingSettings = false
    @State private var store: DotStore
    @State private var fontSize: Double
    @State private var selectedTextRange = NSRange(location: 0, length: 0)
    @State private var notionConfiguration: NotionSyncConfiguration
    @State private var hasNotionToken: Bool
    @State private var isSyncingNotion = false
    @State private var pendingNotionAutoSyncTask: Task<Void, Never>?
    @State private var notionAutoSyncLoopTask: Task<Void, Never>?

    private let onSelectedDotChanged: @MainActor (Dot) -> Void
    private static let fontSizeDefaultsKey = "PanNotesFontSize"
    private static let defaultFontSize = 16.0
    private static let fontSizeRange = 12.0...28.0
    private static let autoSyncDebounceNanoseconds: UInt64 = 2_500_000_000
    private static let autoSyncActivationNanoseconds: UInt64 = 1_000_000_000
    private static let autoSyncPollNanoseconds: UInt64 = 300_000_000_000
    private let onClose: @MainActor () -> Void

    init(workspace: Workspace, store: DotStore) {
        self.init(workspace: workspace, store: store, onSelectedDotChanged: { _ in }, onClose: {})
    }

    init(
        workspace: Workspace,
        store: DotStore,
        onSelectedDotChanged: @escaping @MainActor (Dot) -> Void,
        onClose: @escaping @MainActor () -> Void = {}
    ) {
        self._workspace = State(initialValue: workspace)
        self._selectedDotID = State(initialValue: workspace.manifest.currentDotID)
        self._bodyText = State(initialValue: workspace.bodies[workspace.manifest.currentDotID] ?? "")
        self._viewMode = State(initialValue: workspace.manifest.dots.first?.preferredViewMode ?? .edit)
        self._store = State(initialValue: store)
        self._fontSize = State(initialValue: Self.savedFontSize())
        self._notionConfiguration = State(initialValue: Self.loadNotionConfiguration(rootURL: workspace.rootURL))
        self._hasNotionToken = State(initialValue: Self.hasSavedNotionToken())
        self.onSelectedDotChanged = onSelectedDotChanged
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            DotStripView(
                dots: workspace.manifest.dots,
                theme: workspace.theme,
                selectedDotID: selectedDotID
            ) { dot in
                saveCurrentDot()
                selectedDotID = dot.id
                bodyText = workspace.bodies[dot.id] ?? ""
                selectedTextRange = NSRange(location: 0, length: 0)
                viewMode = dot.preferredViewMode
                onSelectedDotChanged(dot)
            }
            .background(.regularMaterial)

            editorSurface

            bottomBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minWidth: 420, minHeight: 420)
        .overlay(alignment: .topTrailing) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(PanelIconButtonStyle())
            .keyboardShortcut("w", modifiers: .command)
            .help("Close Panel")
            .padding(.top, 10)
            .padding(.trailing, 10)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                workspace: $workspace,
                notionConfiguration: $notionConfiguration,
                hasNotionToken: $hasNotionToken,
                isSyncingNotion: isSyncingNotion,
                onChooseFolder: chooseFolder,
                onSaveManifest: { manifest in
                    do {
                        try store.saveManifest(manifest)
                        statusText = "Settings saved"
                    } catch {
                        statusText = "Settings save failed"
                    }
                },
                onSaveNotionConfiguration: saveNotionConfiguration,
                onSaveNotionToken: saveNotionToken,
                onSetupNotion: setupNotionPages,
                onSyncNotion: syncNotion
            )
        }
        .onAppear {
            startNotionAutoSyncLoop()
            scheduleNotionAutoSync(after: Self.autoSyncActivationNanoseconds)
        }
        .onDisappear {
            stopNotionAutoSyncTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            scheduleNotionAutoSync(after: Self.autoSyncActivationNanoseconds)
        }
        .onChange(of: notionConfiguration.isAutoSyncEnabled) { _, isEnabled in
            if isEnabled {
                scheduleNotionAutoSync(after: Self.autoSyncActivationNanoseconds)
            } else {
                pendingNotionAutoSyncTask?.cancel()
                pendingNotionAutoSyncTask = nil
            }
        }
        .onChange(of: notionConfiguration.isEnabled) { _, isEnabled in
            if isEnabled {
                scheduleNotionAutoSync(after: Self.autoSyncActivationNanoseconds)
            }
        }
    }

    private var editorSurface: some View {
        ZStack(alignment: .topLeading) {
            if viewMode == .edit {
                TextEditorRepresentable(text: $bodyText, selectedRange: $selectedTextRange, fontSize: fontSize)
                    .onChange(of: bodyText) { _, _ in
                        saveCurrentDot()
                        scheduleNotionAutoSync(after: Self.autoSyncDebounceNanoseconds)
                    }
            } else {
                MarkdownPreviewView(
                    nodes: MarkdownPreviewModel.nodes(from: bodyText, rules: workspace.manifest.markdownRules),
                    fontSize: fontSize,
                    onToggleTask: togglePreviewTask
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(PanelIconButtonStyle())
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(PanelIconButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
            .help("Quit")

            quickKeysMenu

            findMenu

            Button {
                syncNotion()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(PanelIconButtonStyle())
            .disabled(isSyncingNotion)
            .help("Sync Notion")

            HStack(spacing: 6) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Slider(value: $fontSize, in: Self.fontSizeRange, step: 1)
                    .controlSize(.mini)
                    .frame(width: 84)
                    .onChange(of: fontSize) { _, value in
                        UserDefaults.standard.set(value, forKey: Self.fontSizeDefaultsKey)
                    }
            }
            .help("Text size")

            Spacer(minLength: 12)

            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker("", selection: $viewMode) {
                Label("Edit", systemImage: "pencil").tag(ViewMode.edit)
                Label("Preview", systemImage: "eye").tag(ViewMode.preview)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .controlSize(.small)
            .frame(width: 150)
        }
        .padding(.horizontal, 14)
        .padding(.top, 7)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var quickKeysMenu: some View {
        Menu {
            Button {
                applyTextCommand(TextCommandProcessor.insertSmartBullet, status: "Inserted smart bullet")
            } label: {
                Label("Smart Bullet", systemImage: "checklist")
            }
            .keyboardShortcut("1", modifiers: .command)

            Button {
                applyTextCommand(TextCommandProcessor.insertBullet, status: "Inserted bullet")
            } label: {
                Label("Bullet", systemImage: "list.bullet")
            }
            .keyboardShortcut("2", modifiers: .command)

            Button {
                applyTextCommand(TextCommandProcessor.insertDivider, status: "Inserted divider")
            } label: {
                Label("Divider", systemImage: "minus")
            }
            .keyboardShortcut("3", modifiers: .command)

            Button {
                insertDate()
            } label: {
                Label("Date", systemImage: "calendar")
            }
            .keyboardShortcut("4", modifiers: .command)

            Button {
                insertTime()
            } label: {
                Label("Time", systemImage: "clock")
            }
            .keyboardShortcut("5", modifiers: .command)
        } label: {
            Image(systemName: "bolt")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 26, height: 26)
        .help("Quick Keys")
    }

    private var findMenu: some View {
        Menu {
            Button {
                PanTextView.performActiveFindAction(.showFindInterface)
            } label: {
                Label("Find", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)

            Button {
                PanTextView.performActiveFindAction(.showReplaceInterface)
            } label: {
                Label("Find and Replace", systemImage: "text.magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: [.command, .option])

            Button {
                PanTextView.performActiveFindAction(.nextMatch)
            } label: {
                Label("Find Next", systemImage: "chevron.down")
            }
            .keyboardShortcut("g", modifiers: .command)

            Button {
                PanTextView.performActiveFindAction(.previousMatch)
            } label: {
                Label("Find Previous", systemImage: "chevron.up")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 26, height: 26)
        .help("Find")
    }

    private func saveCurrentDot() {
        do {
            try store.saveDot(id: selectedDotID, body: bodyText, in: workspace)
            workspace.bodies[selectedDotID] = bodyText
            statusText = "Saved"
        } catch {
            statusText = "Save failed"
        }
    }

    private func chooseFolder() {
        saveCurrentDot()

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let selectedStore = DotStore(rootURL: url)
            do {
                let result = try loadOrMigrateWorkspace(from: selectedStore)
                workspace = result.workspace
                store = selectedStore
                selectedDotID = workspace.manifest.currentDotID
                bodyText = workspace.bodies[selectedDotID] ?? ""
                selectedTextRange = NSRange(location: 0, length: 0)
                viewMode = workspace.manifest.dots.first { $0.id == selectedDotID }?.preferredViewMode ?? .edit
                UserDefaults.standard.set(url.path, forKey: "PanNotesWorkspaceURL")
                notionConfiguration = Self.loadNotionConfiguration(rootURL: workspace.rootURL)
                if let dot = workspace.manifest.dots.first(where: { $0.id == selectedDotID }) {
                    onSelectedDotChanged(dot)
                }
                statusText = result.migrated
                    ? "Copied notes to \(url.lastPathComponent)"
                    : "Folder selected: \(url.lastPathComponent)"
            } catch {
                statusText = "Folder load failed"
            }
        }
    }

    private func loadOrMigrateWorkspace(from store: DotStore) throws -> (workspace: Workspace, migrated: Bool) {
        if try store.hasWorkspaceData() {
            return (try store.load(), false)
        }

        try store.saveWorkspace(workspace)
        return (try store.load(), true)
    }

    private func saveNotionConfiguration(_ configuration: NotionSyncConfiguration) {
        var updated = configuration
        updated.parentPageInput = updated.parentPageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let parentPage = try NotionPageReference(updated.parentPageInput)
            updated.parentPageInput = parentPage.rawValue
            updated.parentPageID = parentPage.pageID
            updated.lastStatus = "Notion parent page set"
        } catch {
            updated.parentPageID = ""
            updated.lastStatus = Self.statusMessage(for: error)
        }
        do {
            try NotionSyncStateStore(rootURL: workspace.rootURL).save(updated)
            notionConfiguration = updated
            statusText = updated.lastStatus
        } catch {
            setNotionStatus("Notion settings save failed")
        }
    }

    @discardableResult
    private func saveNotionToken(_ token: String) -> Bool {
        do {
            try KeychainNotionTokenStore().saveToken(token)
            hasNotionToken = Self.hasSavedNotionToken()
            setNotionStatus(
                hasNotionToken
                    ? "Notion token saved in Keychain. Input cleared for safety."
                    : "Notion token cleared"
            )
            return true
        } catch {
            setNotionStatus(Self.statusMessage(for: error))
            return false
        }
    }

    private func setupNotionPages() {
        Task {
            await runNotionSetup()
        }
    }

    private func syncNotion() {
        pendingNotionAutoSyncTask?.cancel()
        pendingNotionAutoSyncTask = nil
        Task {
            await runNotionSync(isAutomatic: false)
        }
    }

    @MainActor
    private func runNotionSetup() async {
        guard !isSyncingNotion else {
            return
        }

        isSyncingNotion = true
        setNotionStatus("Setting up Notion pages")
        defer {
            isSyncingNotion = false
        }

        do {
            saveCurrentDot()
            let token = try requireNotionToken()
            let configuration = try parsedNotionConfiguration()
            try NotionSyncStateStore(rootURL: workspace.rootURL).save(configuration)
            notionConfiguration = try await makeNotionEngine(token: token).setup(workspace: workspace)
            statusText = notionConfiguration.lastStatus
        } catch {
            setNotionStatus(Self.statusMessage(for: error))
        }
    }

    @MainActor
    private func runNotionSync(isAutomatic: Bool = false) async {
        if isAutomatic {
            guard canRunNotionAutoSync else {
                return
            }
        }
        guard !isSyncingNotion else {
            return
        }

        isSyncingNotion = true
        setNotionStatus(isAutomatic ? "Auto syncing Notion" : "Syncing Notion")
        defer {
            isSyncingNotion = false
        }

        do {
            saveCurrentDot()
            let token = try requireNotionToken()
            let result = try await makeNotionEngine(token: token).sync(workspace: workspace)
            notionConfiguration = result.configuration
            try reloadWorkspaceAfterSync()
            statusText = result.configuration.lastStatus
        } catch {
            setNotionStatus(Self.statusMessage(for: error))
        }
    }

    private var canRunNotionAutoSync: Bool {
        notionConfiguration.isEnabled
            && notionConfiguration.isAutoSyncEnabled
            && hasNotionToken
            && !notionConfiguration.parentPageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func scheduleNotionAutoSync(after delay: UInt64) {
        guard canRunNotionAutoSync else {
            return
        }
        pendingNotionAutoSyncTask?.cancel()
        pendingNotionAutoSyncTask = Task {
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else {
                return
            }
            await runNotionSync(isAutomatic: true)
        }
    }

    private func startNotionAutoSyncLoop() {
        guard notionAutoSyncLoopTask == nil else {
            return
        }
        notionAutoSyncLoopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.autoSyncPollNanoseconds)
                guard !Task.isCancelled else {
                    return
                }
                await runNotionSync(isAutomatic: true)
            }
        }
    }

    private func stopNotionAutoSyncTasks() {
        pendingNotionAutoSyncTask?.cancel()
        pendingNotionAutoSyncTask = nil
        notionAutoSyncLoopTask?.cancel()
        notionAutoSyncLoopTask = nil
    }

    private func setNotionStatus(_ message: String) {
        statusText = message
        notionConfiguration = notionConfiguration.updatingLastStatus(message)
    }

    private func parsedNotionConfiguration() throws -> NotionSyncConfiguration {
        let parentPage = try NotionPageReference(notionConfiguration.parentPageInput)
        var configuration = notionConfiguration
        configuration.parentPageInput = parentPage.rawValue
        configuration.parentPageID = parentPage.pageID
        return configuration
    }

    private func makeNotionEngine(token: String) -> NotionSyncEngine {
        NotionSyncEngine(
            client: NotionAPIClient(token: token),
            stateStore: NotionSyncStateStore(rootURL: workspace.rootURL),
            dotStore: store,
            conflictManager: ConflictManager(rootURL: workspace.rootURL)
        )
    }

    private func requireNotionToken() throws -> String {
        guard let token = try KeychainNotionTokenStore().loadToken(), !token.isEmpty else {
            throw NotionUIError.missingToken
        }
        return token
    }

    private func reloadWorkspaceAfterSync() throws {
        workspace = try store.load()
        if !workspace.manifest.dots.contains(where: { $0.id == selectedDotID }) {
            selectedDotID = workspace.manifest.currentDotID
        }
        bodyText = workspace.bodies[selectedDotID] ?? ""
        selectedTextRange = NSRange(location: 0, length: 0)
        viewMode = workspace.manifest.dots.first { $0.id == selectedDotID }?.preferredViewMode ?? .edit
        if let dot = workspace.manifest.dots.first(where: { $0.id == selectedDotID }) {
            onSelectedDotChanged(dot)
        }
    }

    private static func savedFontSize() -> Double {
        let stored = UserDefaults.standard.double(forKey: fontSizeDefaultsKey)
        guard stored > 0 else {
            return defaultFontSize
        }
        return min(max(stored, fontSizeRange.lowerBound), fontSizeRange.upperBound)
    }

    private static func loadNotionConfiguration(rootURL: URL) -> NotionSyncConfiguration {
        (try? NotionSyncStateStore(rootURL: rootURL).load()) ?? .disabled
    }

    private static func hasSavedNotionToken() -> Bool {
        do {
            return try KeychainNotionTokenStore().loadToken() != nil
        } catch {
            return false
        }
    }

    private static func statusMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func togglePreviewTask(_ taskIndex: Int) {
        guard let result = TextCommandProcessor.toggleTaskItem(at: taskIndex, in: bodyText) else {
            statusText = "Task toggle failed"
            return
        }
        applyTextEditResult(result, status: "Task updated")
    }

    private func applyTextCommand(
        _ command: (String, NSRange) -> TextEditResult,
        status: String
    ) {
        applyTextEditResult(command(bodyText, selectedTextRange), status: status)
    }

    private func insertDate() {
        let date = Self.dateFormatter.string(from: Date())
        applyTextEditResult(
            TextCommandProcessor.insertText(date, in: bodyText, selectedRange: selectedTextRange),
            status: "Inserted date"
        )
    }

    private func insertTime() {
        let time = Self.timeFormatter.string(from: Date())
        applyTextEditResult(
            TextCommandProcessor.insertText(time, in: bodyText, selectedRange: selectedTextRange),
            status: "Inserted time"
        )
    }

    private func applyTextEditResult(_ result: TextEditResult, status: String) {
        bodyText = result.text
        selectedTextRange = result.selectedRange
        workspace.bodies[selectedDotID] = result.text
        do {
            try store.saveDot(id: selectedDotID, body: result.text, in: workspace)
            statusText = status
        } catch {
            statusText = "Save failed"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum NotionUIError: Error, LocalizedError {
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Save a Notion token first."
        }
    }
}

private struct PanelIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(configuration.isPressed ? Color.primary.opacity(0.12) : Color.clear)
            )
            .contentShape(Circle())
    }
}
