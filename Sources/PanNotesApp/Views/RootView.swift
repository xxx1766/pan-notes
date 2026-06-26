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

    private let onSelectedDotChanged: @MainActor (Dot) -> Void

    init(workspace: Workspace, store: DotStore) {
        self.init(workspace: workspace, store: store, onSelectedDotChanged: { _ in })
    }

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping @MainActor (Dot) -> Void) {
        self._workspace = State(initialValue: workspace)
        self._selectedDotID = State(initialValue: workspace.manifest.currentDotID)
        self._bodyText = State(initialValue: workspace.bodies[workspace.manifest.currentDotID] ?? "")
        self._viewMode = State(initialValue: workspace.manifest.dots.first?.preferredViewMode ?? .edit)
        self._store = State(initialValue: store)
        self.onSelectedDotChanged = onSelectedDotChanged
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
                viewMode = dot.preferredViewMode
                onSelectedDotChanged(dot)
            }
            .background(.regularMaterial)

            editorSurface

            bottomBar
        }
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minWidth: 420, minHeight: 420)
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
                TextEditorRepresentable(text: $bodyText)
                    .onChange(of: bodyText) { _, _ in
                        saveCurrentDot()
                    }
            } else {
                MarkdownPreviewView(
                    nodes: MarkdownPreviewModel.nodes(from: bodyText, rules: workspace.manifest.markdownRules)
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
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let selectedStore = DotStore(rootURL: url)
            do {
                workspace = try loadWorkspace(from: selectedStore, rootURL: url)
                store = selectedStore
                selectedDotID = workspace.manifest.currentDotID
                bodyText = workspace.bodies[selectedDotID] ?? ""
                viewMode = workspace.manifest.dots.first { $0.id == selectedDotID }?.preferredViewMode ?? .edit
                UserDefaults.standard.set(url.path, forKey: "PanNotesWorkspaceURL")
                if let dot = workspace.manifest.dots.first(where: { $0.id == selectedDotID }) {
                    onSelectedDotChanged(dot)
                }
                statusText = "Folder selected: \(url.lastPathComponent)"
            } catch {
                statusText = "Folder load failed"
            }
        }
    }

    private func loadWorkspace(from store: DotStore, rootURL: URL) throws -> Workspace {
        let manifestURL = rootURL.appending(path: "manifest.json")
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            return try store.load()
        }
        return try store.bootstrap(dotCount: workspace.manifest.dots.count)
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
