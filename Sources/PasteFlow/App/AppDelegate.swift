import Foundation
import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no Dock icon, menu bar常駐)
        NSApp.setActivationPolicy(.accessory)

        // Setup MenuBar icon
        MenuBarController.shared.setup()

        // Start clipboard polling monitor
        ClipboardMonitor.shared.startMonitoring()

        // Register Global HotKey (Cmd + Shift + V)
        HotKeyManager.shared.onHotKeyTriggered = {
            WindowManager.shared.toggle()
        }
        HotKeyManager.shared.registerDefaultHotKey()

        print("PasteFlow started successfully!")
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.show()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
        ClipboardMonitor.shared.stopMonitoring()
        HotKeyManager.shared.unregister()
    }
}
