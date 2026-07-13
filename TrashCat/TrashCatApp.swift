import SwiftUI

@main
struct TrashCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(coordinator: appDelegate.scanCoordinator)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 540)
    }
}
