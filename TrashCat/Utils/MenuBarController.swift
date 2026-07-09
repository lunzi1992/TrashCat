import AppKit
import SwiftUI

/// Menu bar integration for TrashCat.
/// Shows a cat icon in the menu bar with quick actions.
@MainActor
final class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?

    /// Callback when user wants to open the main window
    var onOpenMain: (() -> Void)?

    /// Callback when user triggers scan from menu bar
    var onScan: (() -> Void)?

    init() {}

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cat.fill", accessibilityDescription: "TrashCat")
            button.title = ""
        }

        let menu = NSMenu()

        // Clean stats
        let thisMonth = ScanHistory.thisMonth()
        if thisMonth > 0 {
            let statsItem = NSMenuItem(
                title: "本月释放 \(thisMonth.formattedSize)",
                action: nil, keyEquivalent: ""
            )
            statsItem.isEnabled = false
            menu.addItem(statsItem)
            menu.addItem(.separator())
        }

        // Scan action
        let scanItem = NSMenuItem(
            title: "开始扫描",
            action: #selector(triggerScan),
            keyEquivalent: "s"
        )
        scanItem.target = self
        menu.addItem(scanItem)

        // Open main window
        let openItem = NSMenuItem(
            title: "打开 TrashCat",
            action: #selector(openMainWindow),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "退出 TrashCat",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    func refreshStats() {
        // Rebuild menu to update stats
        setup()
    }

    @objc private func triggerScan() {
        onScan?()
    }

    @objc private func openMainWindow() {
        onOpenMain?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
