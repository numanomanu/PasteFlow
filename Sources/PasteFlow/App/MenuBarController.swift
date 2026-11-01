import Foundation
import AppKit

@MainActor
public final class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    private override init() {
        super.init()
    }

    public func setup() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "PasteFlow")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "PasteFlow (⌘⇧V)"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        self.statusItem = statusItem
        self.menu = menu
        
        buildMenu()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }

    private func buildMenu() {
        guard let menu = menu else { return }
        menu.removeAllItems()

        // 1. Open PasteFlow
        let openItem = NSMenuItem(
            title: "PasteFlow を開く",
            action: #selector(openPasteFlow),
            keyEquivalent: "v"
        )
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Recent 5 items quick glance
        let recentItems = Array(HistoryStore.shared.items.prefix(5))
        if !recentItems.isEmpty {
            let sectionHeader = NSMenuItem(title: "直近の履歴", action: nil, keyEquivalent: "")
            sectionHeader.isEnabled = false
            menu.addItem(sectionHeader)

            for (index, item) in recentItems.enumerated() {
                var title = item.title
                if title.count > 30 {
                    title = String(title.prefix(30)) + "…"
                }
                let menuItem = NSMenuItem(
                    title: "\(index + 1). \(title)",
                    action: #selector(recentItemClicked(_:)),
                    keyEquivalent: ""
                )
                menuItem.representedObject = item
                menuItem.target = self
                menu.addItem(menuItem)
            }
            menu.addItem(NSMenuItem.separator())
        }

        // 3. Clear History
        let clearItem = NSMenuItem(
            title: "履歴をクリア (お気に入り保持)",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(NSMenuItem.separator())

        // 4. Quit
        let quitItem = NSMenuItem(
            title: "PasteFlow を終了",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func openPasteFlow() {
        WindowManager.shared.toggle()
    }

    @objc private func recentItemClicked(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipItem else { return }
        WindowManager.shared.pasteItemAndHide(item)
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clearHistory(keepPinned: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
