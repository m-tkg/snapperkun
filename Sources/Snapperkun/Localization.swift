import Foundation

/// SwiftPM のリソースバンドル位置を特定するためのトークン（`Bundle(for:)` 用）。
private final class BundleToken {}

/// ローカライズ済み文字列を SwiftPM のリソースバンドルから解決するヘルパー。
///
/// SwiftUI の `Text`/`Button` や AppKit の各種ラベルは既定で `Bundle.main` を参照するため、
/// ここで明示的にリソースバンドルから引いて確定済みの `String` を生成し、各 UI に渡す。
/// 表示言語は OS の優先言語に追従する（en/ja を提供し、既定は en）。
///
/// 新しい GUI 文字列を追加するときは、必ずキーを定義して
/// `Resources/en.lproj` と `Resources/ja.lproj` の両方に対訳を追加すること。
///
/// - Important: SwiftPM 生成の `Bundle.module` は使わない。`Bundle.module` の探索場所は
///   ツールチェーン依存（`.app/Contents/Resources` 配下を見るものと、`.app` 直下を見るものがある）で、
///   見つからないと **`fatalError` で即クラッシュ**する。`bundle.sh` が配置する
///   `Contents/Resources/Snapperkun_Snapperkun.bundle` と探索場所が食い違うとクラッシュするため、
///   複数候補を自前で探索し、見つからなければ `.main` にフォールバックする（クラッシュさせない）。
enum L {
    /// ローカライズ文字列を解決するリソースバンドル。
    private static let bundle: Bundle = {
        let bundleName = "Snapperkun_Snapperkun.bundle"
        let candidates: [URL?] = [
            Bundle.main.resourceURL,                       // .app/Contents/Resources（bundle.sh の配置先）
            Bundle.main.bundleURL,                         // .app 直下 / CLI 実行時の実行ファイル隣（swift run）
            Bundle(for: BundleToken.self).resourceURL,
            Bundle(for: BundleToken.self).bundleURL,
        ]
        for base in candidates.compactMap({ $0 }) {
            let url = base.appendingPathComponent(bundleName)
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // リソースバンドルが見つからない場合は本体バンドルにフォールバックする。
        // （未ローカライズでも起動はさせる。未定義キーは `value:` でキー文字列が返る）
        return .main
    }()

    /// キーに対応するローカライズ文字列を返す。未定義時はキー自体を返す（抜け漏れを可視化するため）。
    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// 書式付きローカライズ文字列。`%@`/`%d` などのプレースホルダに値を埋め込む。
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: .current, arguments: arguments)
    }
}
