import Foundation
import PanNotesCore
import SwiftUI
import WidgetKit

private struct WorkspaceFolderAccess {
    var url: URL
    var isSecurityScoped: Bool

    func withAccess<T>(_ body: (URL) throws -> T) rethrows -> T {
        let didStartAccess = isSecurityScoped && url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try body(url)
    }
}

@MainActor
final class MobileWorkspaceModel: ObservableObject {
    @Published var workspace: Workspace?
    @Published var selectedDotID: String?
    @Published var bodyText = ""
    @Published var statusMessage: String?
    @Published var isShowingFolderPicker = false

    private let defaults: UserDefaults
    private var folderAccess: WorkspaceFolderAccess?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var orderedDots: [Dot] {
        workspace?.manifest.dots.sorted { lhs, rhs in
            if lhs.displayOrder == rhs.displayOrder {
                return lhs.id < rhs.id
            }
            return lhs.displayOrder < rhs.displayOrder
        } ?? []
    }

    func restoreWorkspace() {
        guard folderAccess == nil else {
            return
        }

        guard let bookmark = defaults.data(forKey: PanNotesMobileConstants.workspaceBookmarkKey) else {
            statusMessage = "Choose your iCloud Drive/PanNotes folder."
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            folderAccess = WorkspaceFolderAccess(url: url, isSecurityScoped: true)
            if isStale {
                try saveBookmark(for: url)
            }
            try loadWorkspace(preferredDotID: defaults.string(forKey: PanNotesMobileConstants.selectedDotIDKey))
        } catch {
            statusMessage = "Could not restore the PanNotes folder. Choose it again."
            folderAccess = nil
        }
    }

    func chooseFolder(_ url: URL) {
        do {
            folderAccess = WorkspaceFolderAccess(url: url, isSecurityScoped: true)
            try saveBookmark(for: url)
            try loadWorkspace(preferredDotID: defaults.string(forKey: PanNotesMobileConstants.selectedDotIDKey))
        } catch {
            statusMessage = "Could not open that folder: \(error.localizedDescription)"
            folderAccess = nil
        }
    }

    func selectDot(_ dot: Dot) {
        do {
            try saveCurrentDot()
            selectedDotID = dot.id
            defaults.set(dot.id, forKey: PanNotesMobileConstants.selectedDotIDKey)
            bodyText = workspace?.bodies[dot.id] ?? ""
            try saveCurrentDotSelection(dot.id)
            try publishWidgetSnapshot()
        } catch {
            statusMessage = "Could not save before switching dots: \(error.localizedDescription)"
        }
    }

    func saveCurrentDot() throws {
        guard var workspace, let selectedDotID, let folderAccess else {
            return
        }

        workspace.bodies[selectedDotID] = bodyText
        workspace.manifest.currentDotID = selectedDotID
        if let index = workspace.manifest.dots.firstIndex(where: { $0.id == selectedDotID }) {
            workspace.manifest.dots[index].updatedAt = Date()
        }

        try folderAccess.withAccess { url in
            try DotStore(rootURL: url).saveWorkspace(workspace)
        }

        self.workspace = workspace
        try publishWidgetSnapshot()
        statusMessage = "Saved."
    }

    func refreshFromDisk() {
        do {
            try loadWorkspace(preferredDotID: selectedDotID)
        } catch {
            statusMessage = "Could not refresh: \(error.localizedDescription)"
        }
    }

    private func saveBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: PanNotesMobileConstants.workspaceBookmarkKey)
    }

    private func loadWorkspace(preferredDotID: String?) throws {
        guard let folderAccess else {
            return
        }

        var loaded = try folderAccess.withAccess { url in
            let store = DotStore(rootURL: url)
            if try store.hasWorkspaceData() {
                return try store.load()
            }
            return try store.bootstrap(dotCount: PanNotesMobileConstants.defaultDotCount)
        }

        let selectedID = preferredDotID.flatMap { id in
            loaded.manifest.dots.contains { $0.id == id } ? id : nil
        } ?? loaded.manifest.currentDotID

        loaded.manifest.currentDotID = selectedID
        workspace = loaded
        selectedDotID = selectedID
        defaults.set(selectedID, forKey: PanNotesMobileConstants.selectedDotIDKey)
        bodyText = loaded.bodies[selectedID] ?? ""
        statusMessage = "Loaded \(loaded.rootURL.lastPathComponent)."
        try publishWidgetSnapshot(for: loaded)
    }

    private func saveCurrentDotSelection(_ dotID: String) throws {
        guard var workspace, let folderAccess else {
            return
        }

        workspace.manifest.currentDotID = dotID
        try folderAccess.withAccess { url in
            try DotStore(rootURL: url).saveManifest(workspace.manifest)
        }
        self.workspace = workspace
    }

    private func publishWidgetSnapshot(for workspace: Workspace? = nil) throws {
        guard let workspace = workspace ?? self.workspace else {
            return
        }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PanNotesMobileConstants.appGroupID
        ) else {
            return
        }

        let url = WidgetSnapshotStore.snapshotURL(in: containerURL)
        try WidgetSnapshotStore.save(.make(from: workspace), to: url)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
