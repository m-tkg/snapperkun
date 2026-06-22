import Foundation

/// 修飾キー。Carbon のフラグへの変換は実行ファイル側（HotkeyManager）で行う。
public enum Modifier: String, Codable, CaseIterable, Sendable {
    case command
    case option
    case control
    case shift
}

/// ホットキーのキー組み合わせ。`keyCode` は仮想キーコード（kVK_*）。
public struct KeyCombo: Codable, Equatable, Sendable {
    public var keyCode: UInt32
    public var modifiers: Set<Modifier>

    public init(keyCode: UInt32, modifiers: Set<Modifier>) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}
