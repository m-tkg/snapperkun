import Carbon.HIToolbox
import OSLog
import SnapperCore

private let log = Logger(subsystem: "com.mtkg.snapperkun", category: "hotkey")

/// Carbon の RegisterEventHotKey を用いたグローバルホットキー管理。
/// アクセシビリティ権限とは独立して動作する。
final class HotkeyManager {
    private struct RegisteredHotkey {
        let ref: EventHotKeyRef
        let action: () -> Void
    }

    private var eventHandler: EventHandlerRef?
    private var registered: [UInt32: RegisteredHotkey] = [:]
    private var nextID: UInt32 = 1
    private let signature: OSType = fourCharCode("SNAP")

    /// すべての登録を解除する。
    func unregisterAll() {
        for (_, hotkey) in registered {
            UnregisterEventHotKey(hotkey.ref)
        }
        registered.removeAll()
    }

    /// 設定の Binding 群を登録する（既存はすべて解除してから登録し直す）。
    func register(bindings: [Binding], handler: @escaping (Binding) -> Void) {
        unregisterAll()
        for binding in bindings {
            // ショートカット未割り当て（nil）の Binding は登録しない。
            guard let combo = binding.keyCombo else { continue }
            register(combo) { handler(binding) }
        }
    }

    @discardableResult
    func register(_ combo: KeyCombo, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            carbonModifiers(combo.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            log.error("RegisterEventHotKey failed: keyCode=\(combo.keyCode) status=\(status)")
            return false
        }
        registered[id] = RegisteredHotkey(ref: ref, action: action)
        log.info("registered hotkey id=\(id) keyCode=\(combo.keyCode)")
        return true
    }

    fileprivate func handle(id: UInt32) {
        log.info("hotkey fired id=\(id)")
        registered[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        if status != noErr {
            log.error("InstallEventHandler failed: status=\(status)")
        }
    }

    private func carbonModifiers(_ modifiers: Set<Modifier>) -> UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }

    deinit {
        unregisterAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

/// Carbon の C コールバック。userData 経由で HotkeyManager を取り出して振り分ける。
private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
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
    guard status == noErr else { return noErr }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handle(id: hotKeyID.id)
    return noErr
}

/// 4 文字を OSType（FourCharCode）に変換する。
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for scalar in string.unicodeScalars.prefix(4) {
        result = (result << 8) + OSType(scalar.value & 0xFF)
    }
    return result
}
