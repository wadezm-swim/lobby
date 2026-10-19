import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Uses the Carbon hot key API, which works
/// without asking for Accessibility permission.
///
/// Option+Space normally types a non-breaking space; while Lobby is running the
/// shortcut belongs to the concierge instead.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init?(keyCode: UInt32 = UInt32(kVK_Space), modifiers: UInt32 = UInt32(optionKey), action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            // Carbon calls this on the main thread.
            Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
            return OSStatus(noErr)
        }, 1, &eventType, context, &handlerRef)
        guard installed == OSStatus(noErr) else { return nil }

        let id = EventHotKeyID(signature: OSType(0x4C42_4259), id: 1) // "LBBY"
        let registered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == OSStatus(noErr) else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
