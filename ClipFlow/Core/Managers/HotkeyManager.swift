import Carbon
import Foundation

final class HotkeyManager {
    static let hotkeyPressedNotification = Notification.Name("ClipFlowHotkeyPressed")

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C5654), id: 1) // CLVT

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            NSLog("[ClipFlow] Falha ao registrar hotkey global: \(status)")
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            guard let event else { return noErr }

            var incomingID = EventHotKeyID()
            let eventParamStatus = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &incomingID
            )

            if eventParamStatus == noErr, incomingID.id == 1 {
                NotificationCenter.default.post(name: HotkeyManager.hotkeyPressedNotification, object: nil)
            }
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)
    }

    func unregister() {
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
    }
}
