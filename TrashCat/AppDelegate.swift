import SwiftUI
import AppKit

/// Bridge between the SwiftUI app and the menu bar controller.
/// Owns the menu bar and provides scan/open callbacks.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.setup()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar.teardown()
    }

    /// Called by ContentView on appear to wire up callbacks
    func wire(scanner: ScanCoordinator) {
        menuBar.onScan = { [weak scanner] in
            scanner?.startScan()
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        menuBar.onOpenMain = {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
