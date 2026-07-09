import AppKit
import SwiftUI

/// Menu bar integration for TrashCat.
/// Shows a cat icon in the menu bar with quick actions.
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?

    // Direct callbacks, set in setup() before menu creation
    private var onScan: (() -> Void)?
    private var onOpen: (() -> Void)?

    init() {}

    func setup(onScan: @escaping () -> Void, onOpen: @escaping () -> Void) {
        self.onScan = onScan
        self.onOpen = onOpen

        // Remove old one if any
        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let appIcon = NSApp.applicationIconImage {
                let size = NSSize(width: 18, height: 18)
                let resized = NSImage(size: size)
                resized.lockFocus()
                appIcon.draw(in: NSRect(origin: .zero, size: size),
                             from: .zero, operation: .copy, fraction: 1.0)
                resized.unlockFocus()
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "trash.circle.fill",
                                        accessibilityDescription: "TrashCat")
            }
            button.title = ""
        }

        let menu = buildMenu()
        statusItem?.menu = menu
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    func refreshStats() {
        let menu = buildMenu()
        statusItem?.menu = menu
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

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

        let scanItem = NSMenuItem(
            title: "开始扫描",
            action: #selector(triggerScan),
            keyEquivalent: ""
        )
        scanItem.isEnabled = true
        scanItem.target = self
        menu.addItem(scanItem)

        let openItem = NSMenuItem(
            title: "打开 TrashCat",
            action: #selector(openMainWindow),
            keyEquivalent: ""
        )
        openItem.isEnabled = true
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 TrashCat",
            action: #selector(quitApp),
            keyEquivalent: ""
        )
        quitItem.isEnabled = true
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func triggerScan() {
        onScan?()
    }

    @objc private func openMainWindow() {
        onOpen?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
