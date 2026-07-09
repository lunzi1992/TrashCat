import AppKit
import SwiftUI

/// Menu bar integration for TrashCat.
/// Shows a cat icon in the menu bar with quick actions.
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?

    /// Callback when user wants to open the main window
    var onOpenMain: (() -> Void)?

    /// Callback when user triggers scan from menu bar
    var onScan: (() -> Void)?

    init() {}

    func setup() {
        // Remove old one if any
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use AppIcon from bundle — always available
            if let appIcon = NSApp.applicationIconImage {
                let size = NSSize(width: 16, height: 16)
                let resized = NSImage(size: size)
                resized.lockFocus()
                appIcon.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
                resized.unlockFocus()
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "trash.circle.fill", accessibilityDescription: "TrashCat")
            }
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

        // Scan action — no keyEquivalent to avoid conflict with Cmd+S (Save)
        let scanItem = NSMenuItem(
            title: "开始扫描",
            action: #selector(triggerScan),
            keyEquivalent: ""
        )
        scanItem.target = self
        menu.addItem(scanItem)

        // Open main window — no keyEquivalent to avoid conflict with Cmd+O (Open)
        let openItem = NSMenuItem(
            title: "打开 TrashCat",
            action: #selector(openMainWindow),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        // Quit — no keyEquivalent, leave Cmd+Q to the system
        let quitItem = NSMenuItem(
            title: "退出 TrashCat",
            action: #selector(quitApp),
            keyEquivalent: ""
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
