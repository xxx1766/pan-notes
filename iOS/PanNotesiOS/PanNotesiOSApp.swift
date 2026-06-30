import SwiftUI

@main
struct PanNotesiOSApp: App {
    @StateObject private var model = MobileWorkspaceModel()

    var body: some Scene {
        WindowGroup {
            MobileRootView(model: model)
                .task {
                    model.restoreWorkspace()
                }
        }
    }
}
