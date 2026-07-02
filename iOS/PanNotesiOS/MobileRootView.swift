import SwiftUI

struct MobileRootView: View {
    @ObservedObject var model: MobileWorkspaceModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if model.workspace == nil {
                    EmptyWorkspaceView(model: model)
                } else {
                    EditorView(model: model)
                }
            }
            .navigationTitle("Pan Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        model.refreshFromDisk()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.workspace == nil)

                    Button {
                        model.isShowingFolderPicker = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            }
            .sheet(isPresented: $model.isShowingFolderPicker) {
                FolderPicker { url in
                    model.isShowingFolderPicker = false
                    model.chooseFolder(url)
                }
            }
            .safeAreaInset(edge: .bottom) {
                StatusBar(model: model)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else {
                    return
                }
                try? model.saveCurrentDot()
            }
        }
    }
}

private struct EmptyWorkspaceView: View {
    @ObservedObject var model: MobileWorkspaceModel

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Choose your PanNotes folder")
                .font(.headline)

            Text("Open iCloud Drive and select the PanNotes folder created by the Mac app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                model.isShowingFolderPicker = true
            } label: {
                Label("Choose Folder", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color(.systemBackground))
    }
}

private struct EditorView: View {
    @ObservedObject var model: MobileWorkspaceModel

    var body: some View {
        VStack(spacing: 0) {
            DotStripView(model: model)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Divider()

            TextEditor(text: $model.bodyText)
                .font(.system(size: 17, design: .default))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .onChange(of: model.bodyText) { _, _ in
                    model.statusMessage = nil
                }
        }
    }
}

private struct DotStripView: View {
    @ObservedObject var model: MobileWorkspaceModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(model.orderedDots) { dot in
                    Button {
                        model.selectDot(dot)
                    } label: {
                        VStack(spacing: 5) {
                            Circle()
                                .fill(dotColor(dot))
                                .frame(width: 18, height: 18)
                                .overlay {
                                    if model.selectedDotID == dot.id {
                                        Circle()
                                            .stroke(Color.primary.opacity(0.55), lineWidth: 2)
                                            .frame(width: 28, height: 28)
                                    }
                                }

                            Text("\(dot.displayOrder + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 34, height: 42)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dotColor(_ dot: Dot) -> Color {
        guard let theme = model.workspace?.theme.variants.first(where: { $0.name == dot.themeToken }) else {
            return Color.primary
        }
        return Color(hex: theme.light.dot)
    }
}

private struct StatusBar: View {
    @ObservedObject var model: MobileWorkspaceModel

    var body: some View {
        HStack(spacing: 12) {
            Text(model.statusMessage ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                try? model.saveCurrentDot()
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .disabled(model.workspace == nil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

private extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
