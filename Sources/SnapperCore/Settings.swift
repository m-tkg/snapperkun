import Foundation

/// 1 ホットキーへの割り当て。`specs` が複数あると押すたびに循環する。
/// `keyCombo` が nil の場合はショートカット未割り当て（登録されない）。
public struct Binding: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var keyCombo: KeyCombo?
    public var specs: [SnapSpec]

    public init(id: UUID = UUID(), keyCombo: KeyCombo? = nil, specs: [SnapSpec]) {
        self.id = id
        self.keyCombo = keyCombo
        self.specs = specs
    }
}

/// アプリ全体の設定。
public struct Settings: Codable, Equatable, Sendable {
    public var bindings: [Binding]

    public init(bindings: [Binding]) {
        self.bindings = bindings
    }

    /// 空の設定（初回起動時の初期状態）。
    public static let empty = Settings(bindings: [])
}
