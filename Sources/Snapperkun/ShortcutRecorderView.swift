import AppKit
import SwiftUI
import SnapperCore

/// キー入力を捕捉して KeyCombo を記録する NSView。
final class RecorderNSView: NSView {
    var keyCombo: KeyCombo? { didSet { needsDisplay = true } }
    var onChange: ((KeyCombo) -> Void)?
    /// 記録中だけ設置するローカルキーイベントモニタ。
    /// 矢印キーは SwiftUI/AppKit のフォーカス移動に先に消費され keyDown まで届かないため、
    /// keyDown より前に捕捉して取りこぼしを防ぐ（取り込んだイベントは nil を返して消費する）。
    private var monitor: Any?
    private var recording = false {
        didSet {
            guard recording != oldValue else { return }
            needsDisplay = true
            if recording {
                installMonitor()
            } else {
                removeMonitor()
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 170, height: 24) }

    override func mouseDown(with event: NSEvent) {
        recording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    deinit {
        removeMonitor()
    }

    // MARK: - 記録

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleRecording(event) ?? event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    /// 記録中のキーイベントを処理する。取り込んだら nil（消費）、対象外なら event（素通し）を返す。
    private func handleRecording(_ event: NSEvent) -> NSEvent? {
        guard recording else { return event }
        // Escape は記録キャンセル
        if event.keyCode == 53 {
            recording = false
            window?.makeFirstResponder(nil)
            return nil
        }
        let modifiers = Self.modifiers(from: event.modifierFlags)
        let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        keyCombo = combo
        recording = false
        onChange?(combo)
        window?.makeFirstResponder(nil)
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 2 : 1
        path.stroke()

        let text = recording ? L.string("shortcut.recording") : (keyCombo.map(Self.describe) ?? L.string("shortcut.unset"))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let origin = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        (text as NSString).draw(at: origin, withAttributes: attributes)
    }

    // MARK: - 変換ヘルパー

    static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<Modifier> {
        var result: Set<Modifier> = []
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        return result
    }

    static func describe(_ combo: KeyCombo) -> String {
        var prefix = ""
        if combo.modifiers.contains(.control) { prefix += "⌃" }
        if combo.modifiers.contains(.option) { prefix += "⌥" }
        if combo.modifiers.contains(.shift) { prefix += "⇧" }
        if combo.modifiers.contains(.command) { prefix += "⌘" }
        return prefix + keyName(combo.keyCode)
    }

    /// 代表的な仮想キーコードを表示名に変換する。未知のものは "key N"。
    private static func keyName(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋",
            0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
            0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
            0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
            0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
            0x10: "Y", 0x06: "Z",
            0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
            0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        ]
        return map[keyCode] ?? "key \(keyCode)"
    }
}

/// SwiftUI から使う RecorderNSView のラッパ。
struct ShortcutRecorder: NSViewRepresentable {
    @SwiftUI.Binding var keyCombo: KeyCombo?

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.keyCombo = keyCombo
        view.onChange = { combo in keyCombo = combo }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.keyCombo = keyCombo
    }
}
