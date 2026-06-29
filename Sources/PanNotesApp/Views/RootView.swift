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

    private let onSelectedDotChanged: @MainActor (Dot) -> Void
    private static let fontSizeDefaultsKey = "PanNotesFontSize"
    private static let defaultFontSize = 16.0
    private static let fontSizeRange = 12.0...28.0
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
                onChooseFolder: chooseFolder,
                onSaveManifest: { manifest in
                    do {
                        try store.saveManifest(manifest)
                        statusText = "Settings saved"
                    } catch {
                        statusText = "Settings save failed"
                    }
                }
            )
        }
    }

    private var editorSurface: some View {
        ZStack(alignment: .topLeading) {
            if viewMode == .edit {
                TextEditorRepresentable(text: $bodyText, selectedRange: $selectedTextRange, fontSize: fontSize)
                    .onChange(of: bodyText) { _, _ in
                        saveCurrentDot()
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

    private static func savedFontSize() -> Double {
        let stored = UserDefaults.standard.double(forKey: fontSizeDefaultsKey)
        guard stored > 0 else {
            return defaultFontSize
        }
        return min(max(stored, fontSizeRange.lowerBound), fontSizeRange.upperBound)
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
