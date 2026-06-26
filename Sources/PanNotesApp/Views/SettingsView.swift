import AppKit
import PanNotesCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var workspace: Workspace
    let onChooseFolder: () -> Void
    let onSaveManifest: (Manifest) -> Void

    private let markdownColumns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close")
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsSection(title: "Storage") {
                        Text(workspace.rootURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 6))

                        Button("Choose Folder", action: onChooseFolder)
                            .controlSize(.small)
                    }

                    SettingsSection(title: "Shortcut") {
                        ShortcutRecorderView(defaultsKey: "PanNotesGlobalShortcut")
                            .frame(width: 220, height: 24)
                    }

                    SettingsSection(title: "Markdown") {
                        LazyVGrid(columns: markdownColumns, alignment: .leading, spacing: 9) {
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
                    }

                    SettingsSection(title: "Window") {
                        Toggle("Hide Dock Icon", isOn: preferencesBinding(\.hideDockIcon))
                        Toggle("Close on Focus Loss", isOn: preferencesBinding(\.closeOnFocusLoss))

                        Button {
                            NSApp.terminate(nil)
                        } label: {
                            Label("Quit Pan Notes", systemImage: "power")
                        }
                        .controlSize(.small)
                        .keyboardShortcut("q", modifiers: .command)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 420, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
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

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .font(.system(size: 13))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
