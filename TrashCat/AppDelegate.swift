import SwiftUI
import AppKit

/// Owns app-wide actions shared by the main window and menu bar.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let requestPermissionGuideNotification = Notification.Name("TrashCatRequestPermissionGuide")

    private let menuBar = MenuBarController()
    private let coordinator = ScanCoordinator()
    private var mainWindow: NSWindow?

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

        menuBar.setup(
            isScanning: { [weak self] in self?.coordinator.isScanning ?? false },
            onScan: { [weak self] in self?.requestScan() },
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

    func requestScan() {
        showMainWindow()

        guard PermissionManager.shared.hasFullDiskAccess else {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Self.requestPermissionGuideNotification, object: self)
            }
            return
        }

        coordinator.startScan()
    }

    @discardableResult
    func showMainWindow() -> NSWindow {
        let window = existingMainWindow() ?? createMainWindow()
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === mainWindow else { return }
        mainWindow = nil
    }

    private func existingMainWindow() -> NSWindow? {
        if let mainWindow {
            return mainWindow
        }

        return NSApp.windows.first { window in
            window.isVisible &&
            window.canBecomeKey &&
            window.contentViewController != nil
        }
    }

    private func createMainWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TrashCat"
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.minSize = NSSize(width: 680, height: 500)
        window.center()
        window.contentViewController = NSHostingController(rootView: ContentView(coordinator: coordinator))
        window.delegate = self
        mainWindow = window
        return window
    }
}
