import AppKit
import PanNotesCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var workspace: Workspace
    @Binding var notionConfiguration: NotionSyncConfiguration
    @Binding var hasNotionToken: Bool
    let isSyncingNotion: Bool
    let onChooseFolder: () -> Void
    let onSaveManifest: (Manifest) -> Void
    let onSetOpenAtLogin: (Bool) -> Void
    let onSaveNotionConfiguration: (NotionSyncConfiguration) -> Void
    let onSaveNotionToken: (String) -> Bool
    let onSetupNotion: () -> Void
    let onSyncNotion: () -> Void

    @State private var notionToken = ""

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

                    SettingsSection(title: "Notion Sync") {
                        Toggle("Enable Notion Sync", isOn: notionEnabledBinding)
                        Toggle("Auto Sync", isOn: notionAutoSyncBinding)
                            .disabled(!notionConfiguration.isEnabled)
                            .help("Sync after edits and periodically while Pan Notes is running")

                        HStack(spacing: 8) {
                            SecureField("Integration token", text: $notionToken)
                                .textFieldStyle(.roundedBorder)
                            Button(hasNotionToken ? "Replace Token" : "Save Token") {
                                if onSaveNotionToken(notionToken) {
                                    notionToken = ""
                                }
                            }
                            .disabled(notionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        Text(hasNotionToken ? "Token saved in Keychain. Input clears after saving." : "No token saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Parent page URL or ID", text: notionParentPageBinding)
                            .textFieldStyle(.roundedBorder)

                        HStack(spacing: 8) {
                            Button("Setup Pages", action: onSetupNotion)
                                .disabled(!canUseNotionActions || isSyncingNotion)
                            Button("Sync Now", action: onSyncNotion)
                                .disabled(!canUseNotionActions || isSyncingNotion)
                        }
                        .controlSize(.small)

                        if isSyncingNotion {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Working with Notion")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(notionConfiguration.lastStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
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
                        Toggle("Open at Login", isOn: openAtLoginBinding)

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
        .frame(width: 440, height: 620)
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

    private var openAtLoginBinding: Binding<Bool> {
        Binding(
            get: { workspace.manifest.preferences.openAtLogin },
            set: { value in
                onSetOpenAtLogin(value)
            }
        )
    }

    private var notionEnabledBinding: Binding<Bool> {
        Binding(
            get: { notionConfiguration.isEnabled },
            set: { value in
                notionConfiguration.isEnabled = value
                onSaveNotionConfiguration(notionConfiguration)
            }
        )
    }

    private var notionParentPageBinding: Binding<String> {
        Binding(
            get: { notionConfiguration.parentPageInput },
            set: { value in
                notionConfiguration.parentPageInput = value
                onSaveNotionConfiguration(notionConfiguration)
            }
        )
    }

    private var notionAutoSyncBinding: Binding<Bool> {
        Binding(
            get: { notionConfiguration.isAutoSyncEnabled },
            set: { value in
                notionConfiguration.isAutoSyncEnabled = value
                onSaveNotionConfiguration(notionConfiguration)
            }
        )
    }

    private var canUseNotionActions: Bool {
        hasNotionToken
            && !notionConfiguration.parentPageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
