import Foundation
import OSLog
import SnapperCore

private let log = Logger(subsystem: "com.mtkg.snapperkun", category: "update")

/// 外部プロセスを起動し、終了を待って標準出力を返す簡易ランナー。
enum ProcessRunner {
    struct Failure: Error {
        let exitCode: Int32
        let stderr: String
    }

    static func run(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            process.terminationHandler = { proc in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: String(decoding: outData, as: UTF8.self))
                } else {
                    continuation.resume(throwing: Failure(
                        exitCode: proc.terminationStatus,
                        stderr: String(decoding: errData, as: UTF8.self)
                    ))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// `gh` CLI 経由で GitHub リリースを取得・ダウンロードする。
/// 本リポジトリは private のため、`gh` が認証済みでアクセス権がある環境でのみ動作する。
struct UpdateService {
    static let repoFullName = "m-tkg/snapperkun"

    enum ServiceError: LocalizedError {
        case ghNotFound
        case decodeFailed
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .ghNotFound:
                return "gh コマンドが見つかりません。GitHub CLI のインストールと認証が必要です。"
            case .decodeFailed:
                return "リリース情報の解析に失敗しました。"
            case .commandFailed(let msg):
                return "コマンドが失敗しました: \(msg)"
            }
        }
    }

    /// 現在のアプリバージョン（CFBundleShortVersionString）。
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// 最新リリース情報を取得する。
    func fetchLatestRelease() async throws -> ReleaseInfo {
        let gh = try ghPath()
        let json: String
        do {
            json = try await ProcessRunner.run(
                executable: gh,
                arguments: ["api", "repos/\(Self.repoFullName)/releases/latest"]
            )
        } catch let failure as ProcessRunner.Failure {
            throw ServiceError.commandFailed(failure.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let release = try? JSONDecoder().decode(ReleaseInfo.self, from: Data(json.utf8)) else {
            throw ServiceError.decodeFailed
        }
        return release
    }

    /// 指定タグのリリースから zip 資産を `directory` にダウンロードする。
    func downloadLatestReleaseZip(tag: String, into directory: URL) async throws {
        let gh = try ghPath()
        log.info("Downloading release \(tag, privacy: .public)")
        do {
            _ = try await ProcessRunner.run(
                executable: gh,
                arguments: ["release", "download", tag,
                            "--repo", Self.repoFullName,
                            "--pattern", "*.zip",
                            "--dir", directory.path,
                            "--clobber"]
            )
        } catch let failure as ProcessRunner.Failure {
            throw ServiceError.commandFailed(failure.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func ghPath() throws -> String {
        let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        if let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return found
        }
        log.error("gh not found in known paths")
        throw ServiceError.ghNotFound
    }
}
