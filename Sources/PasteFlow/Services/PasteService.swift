import Foundation
import AppKit
import ApplicationServices

@MainActor
public final class PasteService {
    public static let shared = PasteService()

    private init() {}

    /// Check if accessibility permissions are granted for simulating keystrokes
    public var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt user to enable accessibility in System Settings (ONLY called explicitly from Preferences)
    public func promptForAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Copy item to pasteboard and automatically paste into previous application if permitted
    public func paste(item: ClipItem, targetApp: NSRunningApplication?, plainTextOnly: Bool = false) {
        // 1. Always copy to pasteboard first
        copyToClipboard(item: item, plainTextOnly: plainTextOnly)

        // 2. Reactivate target application if valid and not ourselves
        let myBundleId = Bundle.main.bundleIdentifier
        let appToActivate = (targetApp?.bundleIdentifier != myBundleId) ? targetApp : nil
        appToActivate?.activate()

        // 3. Verify accessibility permission before attempting synthetic keystrokes
        guard isAccessibilityTrusted else {
            print("⚠️ PasteFlow: Accessibility permission not granted. Simulated ⌘V skipped. Text is copied to clipboard.")
            return
        }

        // 4. Poll until target application has become active (up to 300ms) or short delay, then simulate Cmd+V
        Task { @MainActor in
            let maxWaitIterations = 30 // 30 * 10ms = 300ms max
            var iterations = 0

            if let app = appToActivate {
                while !app.isActive && iterations < maxWaitIterations {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    iterations += 1
                }
            } else {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms fallback
            }

            // Small stabilization buffer for WindowServer focus settling
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            self.simulatePasteKeystroke()
        }
    }

    /// Copy item to pasteboard only without pasting
    public func copyToClipboard(item: ClipItem, plainTextOnly: Bool = false) {
        ClipboardMonitor.shared.suppressNextRecording()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .link, .color:
            if let text = item.plainText {
                pasteboard.setString(text, forType: .string)
            }
            if !plainTextOnly {
                if let rtf = item.richTextRTF {
                    pasteboard.setData(rtf, forType: .rtf)
                }
                if let html = item.htmlContent {
                    pasteboard.setString(html, forType: .html)
                }
            }

        case .image:
            if let fileName = item.imageFileName,
               let image = HistoryStore.shared.loadImage(fileName: fileName) {
                pasteboard.writeObjects([image])
            }

        case .file:
            if let urlStrings = item.fileURLs {
                let urls = urlStrings.compactMap { URL(string: $0) }
                pasteboard.writeObjects(urls as [NSURL])
            } else if let path = item.plainText {
                pasteboard.setString(path, forType: .string)
            }
        }
    }

    /// Simulate Cmd + V via CGEvent with hidSystemState
    private func simulatePasteKeystroke() {
        guard isAccessibilityTrusted else { return }

        // Use hidSystemState so modifier key states from prior user taps do not taint the synthetic event
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 0x09 // 'v'

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = []

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
