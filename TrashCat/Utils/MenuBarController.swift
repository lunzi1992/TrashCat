import AppKit

/// Menu bar integration — uses explicit button target/action + manual menu popup.
/// This avoids the NSStatusItem.menu property which can be unreliable in SwiftUI lifecycle apps.
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?

    private var onScan: (() -> Void)?
    private var onOpen: (() -> Void)?

    init() {}

    func setup(onScan: @escaping () -> Void, onOpen: @escaping () -> Void) {
        self.onScan = onScan
        self.onOpen = onOpen

        if let existing = statusItem {
            NSStatusBar.system.removeStatusItem(existing)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Use a reliable SF Symbol that definitely exists
        if let img = NSImage(systemSymbolName: "trash.circle", accessibilityDescription: "TrashCat") {
            img.isTemplate = true  // adapts to system appearance
            button.image = img
        }

        // Explicit target/action — click the button shows the menu
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseDown, .rightMouseDown])
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let menu = buildMenu()
        // Manually pop up the menu at the status bar button
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: sender.bounds.maxY),
                   in: sender)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let thisMonth = ScanHistory.thisMonth()
        if thisMonth > 0 {
            let stats = NSMenuItem(title: "本月释放 \(thisMonth.formattedSize)", action: nil, keyEquivalent: "")
            stats.isEnabled = false
            menu.addItem(stats)
            menu.addItem(.separator())
        }

        let scanItem = NSMenuItem(title: "开始扫描", action: #selector(triggerScan), keyEquivalent: "")
        scanItem.target = self; scanItem.isEnabled = true
        menu.addItem(scanItem)

        let openItem = NSMenuItem(title: "打开 TrashCat", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self; openItem.isEnabled = true
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 TrashCat", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self; quitItem.isEnabled = true
        menu.addItem(quitItem)

        return menu
    }

    @objc private func triggerScan() { onScan?() }
    @objc private func openMainWindow() { onOpen?(); NSApp.activate(ignoringOtherApps: true) }
    @objc private func quitApp() { NSApp.terminate(nil) }
}
