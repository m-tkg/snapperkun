import Foundation

/// ローカライズ済み文字列を `Bundle.module`（SwiftPM のリソースバンドル）から解決するヘルパー。
///
/// SwiftUI の `Text`/`Button` や AppKit の各種ラベルは既定で `Bundle.main` を参照するため、
/// ここで明示的に `.module` から引いて確定済みの `String` を生成し、各 UI に渡す。
/// 表示言語は OS の優先言語に追従する（en/ja を提供し、既定は en）。
///
/// 新しい GUI 文字列を追加するときは、必ずキーを定義して
/// `Resources/en.lproj` と `Resources/ja.lproj` の両方に対訳を追加すること。
enum L {
    /// キーに対応するローカライズ文字列を返す。未定義時はキー自体を返す（抜け漏れを可視化するため）。
    static func string(_ key: String) -> String {
        Bundle.module.localizedString(forKey: key, value: key, table: nil)
    }

    /// 書式付きローカライズ文字列。`%@`/`%d` などのプレースホルダに値を埋め込む。
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }
}
