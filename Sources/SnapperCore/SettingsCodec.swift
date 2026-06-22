import Foundation

/// 設定の JSON エンコード/デコード。永続化（SettingsStore）と import/export で共有する。
public enum SettingsCodec {
    /// 設定を整形済み JSON データに変換する。
    public static func data(from settings: Settings) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(settings)
    }

    /// JSON データから設定を復元する。不正なデータは throw。
    public static func settings(from data: Data) throws -> Settings {
        try JSONDecoder().decode(Settings.self, from: data)
    }
}
