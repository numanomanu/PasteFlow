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
    private var appActivationObserver: Any?

    private init() {
        setupPanel()
        setupAppActivationObserver()
    }

    private func setupAppActivationObserver() {
        // Track the frontmost application continuously so previousApp is always up to date
        // even when invoked via menu bar or hotkey.
        let myBundleId = Bundle.main.bundleIdentifier
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            if let myBundleId = myBundleId, app.bundleIdentifier == myBundleId {
                return
            }
            Task { @MainActor [weak self] in
                self?.previousApp = app
            }
        }

        // Initialize with current frontmost application
        if let current = NSWorkspace.shared.frontmostApplication,
           current.bundleIdentifier != myBundleId {
            previousApp = current
        }
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

        // Always reset to main list view and clear search on open
        showingPreferences = false
        HistoryStore.shared.searchText = ""
        HistoryStore.shared.selectFirstItem()

        // Capture the currently frontmost application before showing our panel
        let frontApp = NSWorkspace.shared.frontmostApplication
        let myBundleId = Bundle.main.bundleIdentifier
        if let front = frontApp, front.bundleIdentifier != myBundleId {
            previousApp = front
            NSLog("PasteFlow: show() captured previousApp: \(front.localizedName ?? "unknown") (\(front.bundleIdentifier ?? ""))")
        }

        // Center on the active screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (panel.frame.width / 2)
            let y = screenRect.midY - (panel.frame.height / 2) + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Make panel key window without activating NSApp, keeping previousApp frontmost
        panel.makeKeyAndOrderFront(nil)
        isVisible = true

        startMonitoringOutsideClicks()
    }

    public func hide() {
        guard isVisible else { return }
        stopMonitoringOutsideClicks()
        panel?.orderOut(nil)
        isVisible = false
        showingPreferences = false
        // Do NOT call NSApp.hide(nil); orderOut(nil) allows macOS to smoothly maintain previousApp focus.
    }

    public func pasteSelectedAndHide(plainTextOnly: Bool = false) {
        guard let item = HistoryStore.shared.selectedItem else {
            NSLog("PasteFlow: pasteSelectedAndHide aborted because selectedItem is nil")
            hide()
            return
        }
        let targetApp = previousApp
        NSLog("PasteFlow: pasteSelectedAndHide for targetApp: \(targetApp?.localizedName ?? "nil"), plain: \(plainTextOnly)")
        hide()
        PasteService.shared.paste(item: item, targetApp: targetApp, plainTextOnly: plainTextOnly)
    }

    public func copySelectedAndHide(plainTextOnly: Bool = false) {
        guard let item = HistoryStore.shared.selectedItem else {
            hide()
            return
        }
        hide()
        PasteService.shared.copyToClipboard(item: item, plainTextOnly: plainTextOnly)
    }

    public func pasteItemAndHide(_ item: ClipItem, plainTextOnly: Bool = false) {
        let targetApp = previousApp
        hide()
        PasteService.shared.paste(item: item, targetApp: targetApp, plainTextOnly: plainTextOnly)
    }

    // MARK: - KeyEventHandler

    public func handleKeyDown(event: NSEvent) -> Bool {
        let store = HistoryStore.shared
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // ESC key (key code 53)
        if event.keyCode == 53 {
            if showingPreferences {
                showingPreferences = false
                return true
            }
            if !store.searchText.isEmpty {
                store.searchText = ""
                store.selectFirstItem()
                return true
            }
            hide()
            return true
        }

        // When preferences view is open, do not handle list navigation
        if showingPreferences {
            return false
        }

        let hasNavigationModifiers = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)

        // Return / Enter (key code 36: Return, key code 76: Keypad Enter)
        // Normal Enter -> Rich paste; Shift + Enter -> Plain text paste
        if (event.keyCode == 36 || event.keyCode == 76) && !hasNavigationModifiers {
            let isShift = flags.contains(.shift)
            NSLog("PasteFlow: Enter key pressed (keyCode: \(event.keyCode), isShift: \(isShift))")
            pasteSelectedAndHide(plainTextOnly: isShift)
            return true
        }

        // Up arrow (key code 126) without modifiers
        if event.keyCode == 126 && !hasNavigationModifiers && !flags.contains(.shift) {
            store.selectPrevious()
            return true
        }

        // Down arrow (key code 125) without modifiers
        if event.keyCode == 125 && !hasNavigationModifiers && !flags.contains(.shift) {
            store.selectNext()
            return true
        }

        // Tab key (key code 48): Cycle through filter categories
        if event.keyCode == 48 && !flags.contains(.command) && !flags.contains(.option) && !flags.contains(.control) {
            let isShift = flags.contains(.shift)
            withAnimation(.easeInOut(duration: 0.15)) {
                if isShift {
                    store.selectPreviousCategory()
                } else {
                    store.selectNextCategory()
                }
            }
            return true
        }

        // Cmd + 1 ~ Cmd + 9 for direct pasting top items (Cmd + Shift + 1-9 for plain text)
        if flags.contains(.command) {
            let isShift = flags.contains(.shift)
            let numberKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
            if let index = numberKeyCodes.firstIndex(of: event.keyCode) {
                if let item = store.selectIndex(index) {
                    pasteItemAndHide(item, plainTextOnly: isShift)
                    return true
                }
            }

            // Cmd + C or Cmd + Shift + C: Copy without pasting
            if event.charactersIgnoringModifiers == "c" {
                copySelectedAndHide(plainTextOnly: isShift)
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
