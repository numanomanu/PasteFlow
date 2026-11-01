import Foundation
import Carbon
import AppKit

@MainActor
public final class HotKeyManager {
    public static let shared = HotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    public var onHotKeyTriggered: (() -> Void)?

    private init() {}

    public func registerDefaultHotKey() {
        // Default: Cmd + Shift + V
        // Carbon key codes: 'v' is 9 (kVK_ANSI_V)
        let keyCode: UInt32 = 9
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        register(keyCode: keyCode, modifiers: modifiers)
    }

    public func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerFunction: EventHandlerUPP = { _, event, _ in
            guard let event = event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                DispatchQueue.main.async {
                    HotKeyManager.shared.handleTrigger()
                }
            }
            return noErr
        }

        let installErr = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerFunction,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        if installErr != noErr {
            print("Failed to install event handler: \(installErr)")
            return
        }

        let hotKeyID = EventHotKeyID(
            signature: OSType(0x50464C57), // 'PFLW'
            id: 1
        )

        let regErr = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if regErr != noErr {
            print("Failed to register hot key: \(regErr)")
        } else {
            print("PasteFlow hotkey (Cmd + Shift + V) registered successfully!")
        }
    }

    private func handleTrigger() {
        onHotKeyTriggered?()
    }

    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        // cleanup
    }
}
