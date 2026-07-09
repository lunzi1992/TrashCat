import SwiftUI
import AppKit

/// AppDelegate that owns the menu bar and scan coordinator directly.
/// No closure wiring — direct references, no timing issues.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()
    private let coordinator = ScanCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register scanners once
        let ruleScanners: [Scannable] = RuleRegistry.all
            .filter { !$0.paths.isEmpty }
            .map { RuleScanner(rule: $0) }
        coordinator.registerAll(ruleScanners)
        coordinator.register(BrowserCacheScanner())
        coordinator.register(OrphanScanner())
        coordinator.register(SpaceDiagnosticScanner())
        coordinator.didRegister = true

        // Setup menu bar with direct action references
        menuBar.setup(
            onScan: { [weak self] in
                self?.coordinator.startScan()
                self?.showMainWindow()
            },
            onOpen: { [weak self] in
                self?.showMainWindow()
            }
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar.teardown()
    }

    /// Exposed for ContentView to use the same coordinator
    var scanCoordinator: ScanCoordinator { coordinator }

    private func showMainWindow() {
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
