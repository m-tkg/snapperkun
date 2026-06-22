import Foundation

/// 設定を JSON ファイルに永続化する。読み込み失敗時は既定値にフォールバックする。
public final class SettingsStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// 既定の保存先: ~/Library/Application Support/Snapperkun/settings.json
    public static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("Snapperkun", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// 設定を読み込む。ファイルが無い・壊れている場合は `Settings.empty` を返す。
    public func load() -> Settings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? SettingsCodec.settings(from: data) else {
            return .empty
        }
        return settings
    }

    /// 設定を保存する。中間ディレクトリが無ければ作成する。
    public func save(_ settings: Settings) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try SettingsCodec.data(from: settings)
        try data.write(to: url, options: .atomic)
    }
}
