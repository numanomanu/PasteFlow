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
    public func paste(item: ClipItem, targetApp: NSRunningApplication?) {
        // 1. Always copy to pasteboard first
        copyToClipboard(item: item)

        // 2. Hide PasteFlow application so macOS returns focus to the target app
        NSApp.hide(nil)

        // 3. Re-activate previous application if available
        if let targetApp = targetApp, targetApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp.activate()
        }

        // 4. If accessibility is trusted, simulate Cmd+V after focus settles
        // NEVER spam system prompt dialogs during normal paste operations!
        guard isAccessibilityTrusted else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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

    /// Simulate Cmd + V via CGEvent (clean, silent, no AppleScript automation prompts)
    private func simulatePasteKeystroke() {
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
