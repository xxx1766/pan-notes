import PanNotesCore
import SwiftUI

struct RootView: View {
    @State private var workspace: Workspace
    @State private var selectedDotID: String
    @State private var bodyText: String
    @State private var viewMode: ViewMode
    @State private var statusText = "Saved"

    private let store: DotStore
    private let onSelectedDotChanged: @MainActor (Dot) -> Void

    init(workspace: Workspace, store: DotStore) {
        self.init(workspace: workspace, store: store, onSelectedDotChanged: { _ in })
    }

    init(workspace: Workspace, store: DotStore, onSelectedDotChanged: @escaping @MainActor (Dot) -> Void) {
        self._workspace = State(initialValue: workspace)
        self._selectedDotID = State(initialValue: workspace.manifest.currentDotID)
        self._bodyText = State(initialValue: workspace.bodies[workspace.manifest.currentDotID] ?? "")
        self._viewMode = State(initialValue: workspace.manifest.dots.first?.preferredViewMode ?? .edit)
        self.store = store
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
            Divider()
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
            Divider()
            HStack {
                Picker("", selection: $viewMode) {
                    Text("Edit").tag(ViewMode.edit)
                    Text("Preview").tag(ViewMode.preview)
                }
                .pickerStyle(.segmented)
                Spacer()
                Text(statusText)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 420, minHeight: 420)
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
}
