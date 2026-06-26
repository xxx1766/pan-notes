import PanNotesCore
import SwiftUI

struct SettingsView: View {
    @Binding var workspace: Workspace
    let onChooseFolder: () -> Void
    let onSaveManifest: (Manifest) -> Void

    var body: some View {
        Form {
            Section("Storage") {
                Text(workspace.rootURL.path)
                    .font(.caption)
                    .textSelection(.enabled)
                Button("Choose Folder", action: onChooseFolder)
            }
            Section("Shortcut") {
                ShortcutRecorderView(defaultsKey: "PanNotesGlobalShortcut")
                    .frame(width: 220, height: 24)
            }
            Section("Markdown") {
                Toggle("Headings", isOn: binding(\.headings))
                Toggle("Emphasis", isOn: binding(\.emphasis))
                Toggle("Lists", isOn: binding(\.lists))
                Toggle("Task Lists", isOn: binding(\.taskLists))
                Toggle("Links", isOn: binding(\.links))
                Toggle("Inline Code", isOn: binding(\.inlineCode))
                Toggle("Code Blocks", isOn: binding(\.codeBlocks))
                Toggle("Block Quotes", isOn: binding(\.blockQuotes))
                Toggle("Tables", isOn: binding(\.tables))
                Toggle("Strikethrough", isOn: binding(\.strikethrough))
            }
            Section("Window") {
                Toggle("Hide Dock Icon", isOn: preferencesBinding(\.hideDockIcon))
                Toggle("Close on Focus Loss", isOn: preferencesBinding(\.closeOnFocusLoss))
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func binding(_ keyPath: WritableKeyPath<MarkdownRules, Bool>) -> Binding<Bool> {
        Binding(
            get: { workspace.manifest.markdownRules[keyPath: keyPath] },
            set: { value in
                workspace.manifest.markdownRules[keyPath: keyPath] = value
                onSaveManifest(workspace.manifest)
            }
        )
    }

    private func preferencesBinding(_ keyPath: WritableKeyPath<AppPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { workspace.manifest.preferences[keyPath: keyPath] },
            set: { value in
                workspace.manifest.preferences[keyPath: keyPath] = value
                onSaveManifest(workspace.manifest)
            }
        )
    }
}
