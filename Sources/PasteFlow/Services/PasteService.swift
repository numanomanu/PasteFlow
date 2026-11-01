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

    /// Prompt user to enable accessibility in System Settings
    public func promptForAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Copy item to pasteboard and automatically paste into previous application
    public func paste(item: ClipItem, targetApp: NSRunningApplication?) {
        copyToClipboard(item: item)

        guard let targetApp = targetApp, targetApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }

        // Activate previous application
        targetApp.activate()

        // Small delay to ensure the application has regained focus before posting keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePasteKeystroke()
        }
    }

    /// Copy item to pasteboard only without pasting
    public func copyToClipboard(item: ClipItem) {
        ClipboardMonitor.shared.suppressNextRecording()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .link, .color:
            if let text = item.plainText {
                pasteboard.setString(text, forType: .string)
            }
            if let rtf = item.richTextRTF {
                pasteboard.setData(rtf, forType: .rtf)
            }
            if let html = item.htmlContent {
                pasteboard.setString(html, forType: .html)
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

    /// Simulate Cmd + V using CGEvent
    private func simulatePasteKeystroke() {
        guard isAccessibilityTrusted else {
            print("Accessibility permission not granted. Keystroke simulation skipped.")
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // 'v'

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
