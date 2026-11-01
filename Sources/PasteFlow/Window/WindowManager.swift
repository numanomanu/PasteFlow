import Foundation
import AppKit
import SwiftUI

@MainActor
public final class WindowManager: ObservableObject, KeyEventHandler {
    public static let shared = WindowManager()

    @Published public var isVisible: Bool = false
    @Published public var showingPreferences: Bool = false
    public private(set) var previousApp: NSRunningApplication?

    private var panel: FloatingPanel?
    private var globalClickMonitor: Any?

    private init() {
        setupPanel()
    }

    private func setupPanel() {
        let width: CGFloat = 740
        let height: CGFloat = 480
        let initialRect = NSRect(x: 0, y: 0, width: width, height: height)

        let panel = FloatingPanel(contentRect: initialRect)
        panel.keyDelegate = self
        panel.center()

        let contentView = MainPopupView()
            .environmentObject(HistoryStore.shared)
            .environmentObject(self)

        panel.contentView = NSHostingView(rootView: contentView)
        self.panel = panel
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        guard let panel = panel else { return }

        // Always reset to main list view when opening
        showingPreferences = false

        // Track frontmost app before showing so we can restore focus and paste into it
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontApp
        }

        // Reset search query or selection if desired
        HistoryStore.shared.selectFirstItem()

        // Center on the active screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (panel.frame.width / 2)
            let y = screenRect.midY - (panel.frame.height / 2) + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true

        startMonitoringOutsideClicks()
    }

    public func hide() {
        guard isVisible else { return }
        stopMonitoringOutsideClicks()
        panel?.orderOut(nil)
        isVisible = false
        showingPreferences = false
    }

    public func pasteSelectedAndHide() {
        guard let item = HistoryStore.shared.selectedItem else {
            hide()
            return
        }
        let targetApp = previousApp
        hide()
        PasteService.shared.paste(item: item, targetApp: targetApp)
    }

    public func copySelectedAndHide() {
        guard let item = HistoryStore.shared.selectedItem else {
            hide()
            return
        }
        hide()
        PasteService.shared.copyToClipboard(item: item)
    }

    public func pasteItemAndHide(_ item: ClipItem) {
        let targetApp = previousApp
        hide()
        PasteService.shared.paste(item: item, targetApp: targetApp)
    }

    // MARK: - KeyEventHandler

    public func handleKeyDown(event: NSEvent) -> Bool {
        let store = HistoryStore.shared

        // ESC key (key code 53): Always close the window immediately
        if event.keyCode == 53 {
            hide()
            return true
        }

        // When preferences view is open, do not handle list navigation
        if showingPreferences {
            return false
        }

        // Return / Enter (key code 36)
        if event.keyCode == 36 {
            pasteSelectedAndHide()
            return true
        }

        // Up arrow (key code 126)
        if event.keyCode == 126 {
            store.selectPrevious()
            return true
        }

        // Down arrow (key code 125)
        if event.keyCode == 125 {
            store.selectNext()
            return true
        }

        // Tab key (key code 48): Cycle through filter categories
        if event.keyCode == 48 {
            let isShift = event.modifierFlags.contains(.shift)
            withAnimation(.easeInOut(duration: 0.15)) {
                if isShift {
                    store.selectPreviousCategory()
                } else {
                    store.selectNextCategory()
                }
            }
            return true
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Cmd + 1 ~ Cmd + 9 for direct pasting top items
        if flags.contains(.command) {
            // Number keys 1-9: keyCodes 18, 19, 20, 21, 23, 22, 26, 28, 25
            let numberKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
            if let index = numberKeyCodes.firstIndex(of: event.keyCode) {
                if let item = store.selectIndex(index) {
                    pasteItemAndHide(item)
                    return true
                }
            }

            // Cmd + C: Copy without pasting
            if event.charactersIgnoringModifiers == "c" {
                copySelectedAndHide()
                return true
            }

            // Cmd + P or Cmd + F: Toggle Favorite
            if event.charactersIgnoringModifiers == "p" || event.charactersIgnoringModifiers == "f" {
                if let item = store.selectedItem {
                    store.toggleFavorite(id: item.id)
                    return true
                }
            }

            // Cmd + Delete / Backspace: Delete item
            if event.keyCode == 51 {
                if let item = store.selectedItem {
                    store.delete(id: item.id)
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Outside Click Monitoring

    private func startMonitoringOutsideClicks() {
        stopMonitoringOutsideClicks()
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self = self, self.isVisible else { return }
                if let panel = self.panel {
                    let mouseLocation = NSEvent.mouseLocation
                    if !panel.frame.contains(mouseLocation) {
                        self.hide()
                    }
                }
            }
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
    }
}
