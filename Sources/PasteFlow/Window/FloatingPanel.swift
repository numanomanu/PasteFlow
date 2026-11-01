import Foundation
import AppKit
import SwiftUI

@MainActor
public protocol KeyEventHandler: AnyObject {
    func handleKeyDown(event: NSEvent) -> Bool
}

public final class FloatingPanel: NSPanel {
    public weak var keyDelegate: KeyEventHandler?

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.minSize = NSSize(width: 600, height: 380)
    }

    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }

    public override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            // If the user is currently composing marked text in IME (e.g. Japanese IME),
            // let Enter/Return confirm the marked text rather than triggering paste.
            let isComposing: Bool
            if let textView = firstResponder as? NSTextView {
                isComposing = textView.hasMarkedText()
            } else {
                isComposing = false
            }

            if event.keyCode == 36 || event.keyCode == 76 {
                if isComposing {
                    super.sendEvent(event)
                    return
                }
            }

            if let keyDelegate = keyDelegate, keyDelegate.handleKeyDown(event: event) {
                return // Event handled and intercepted before reaching firstResponder
            }
        }
        super.sendEvent(event)
    }

    public override func keyDown(with event: NSEvent) {
        if let keyDelegate = keyDelegate, keyDelegate.handleKeyDown(event: event) {
            return
        }
        super.keyDown(with: event)
    }
}
