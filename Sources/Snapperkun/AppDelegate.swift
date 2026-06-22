import AppKit
import OSLog
import SnapperCore

private let log = Logger(subsystem: "com.mtkg.snapperkun", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore(url: SettingsStore.defaultURL())
    private let hotkeyManager = HotkeyManager()
    private let engine = SnapEngine()
    private var statusBar: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var settings = Settings.empty

    private let updateService = UpdateService()
    private lazy var selfUpdater = SelfUpdater(service: updateService)
    private var availableRelease: ReleaseInfo?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ウィンドウ操作に必要なアクセシビリティ権限を要求する。
        AccessibilityPermission.requestIfNeeded()

        settings = store.load()

        statusBar = StatusBarController(
            openSettings: { [weak self] in self?.openSettings() },
            checkPermission: { AccessibilityPermission.requestIfNeeded() },
            checkForUpdate: { [weak self] in self?.startUpdateCheck(interactive: true) },
            quit: { NSApp.terminate(nil) }
        )

        reloadHotkeys()

        // 起動時にサイレントで更新チェック（あればメニュー文言を変更）。
        startUpdateCheck(interactive: false)
    }

    private func reloadHotkeys() {
        let assigned = settings.bindings.filter { $0.keyCombo != nil }.count
        log.info("reloadHotkeys: bindings=\(self.settings.bindings.count) assigned=\(assigned) axTrusted=\(AccessibilityPermission.isTrusted)")
        hotkeyManager.register(bindings: settings.bindings) { [weak self] binding in
            DispatchQueue.main.async { self?.engine.handle(binding: binding) }
        }
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                initialSettings: settings,
                onApply: { [weak self] newSettings in
                    guard let self else { return }
                    self.settings = newSettings
                    try? self.store.save(newSettings)
                    self.reloadHotkeys()
                }
            )
        }
        settingsWindowController?.show()
    }

    // MARK: - アップデート

    /// 最新リリースを取得してバージョン比較する。
    /// interactive=false: 起動時のサイレントチェック（結果はメニュー文言に反映するのみ）。
    /// interactive=true : メニューからの手動チェック（結果をダイアログで提示）。
    private func startUpdateCheck(interactive: Bool) {
        Task { @MainActor in
            do {
                let release = try await updateService.fetchLatestRelease()
                let isNewer = VersionComparator.isNewer(
                    tag: release.tagName, than: UpdateService.currentVersion)
                if isNewer {
                    availableRelease = release
                    statusBar?.setUpdateAvailable(tag: release.tagName)
                } else {
                    availableRelease = nil
                    statusBar?.clearUpdateAvailable()
                }
                if interactive {
                    if isNewer {
                        promptInstall(release)
                    } else {
                        showInfo("最新版です（v\(UpdateService.currentVersion)）。")
                    }
                }
            } catch {
                log.error("update check failed: \(error.localizedDescription, privacy: .public)")
                if interactive {
                    showError("アップデートの確認に失敗しました。\n\(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    private func promptInstall(_ release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "新しいバージョン \(release.tagName) があります"
        alert.informativeText = "現在: v\(UpdateService.currentVersion)\n更新するとアプリを再起動します。"
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "リリースページを開く")
        alert.addButton(withTitle: "キャンセル")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            performUpdate(release)
        case .alertSecondButtonReturn:
            if let url = URL(string: release.htmlUrl) { NSWorkspace.shared.open(url) }
        default:
            break
        }
    }

    @MainActor
    private func performUpdate(_ release: ReleaseInfo) {
        Task { @MainActor in
            do {
                try await selfUpdater.performUpdate(to: release)
                // 成功時はアプリが終了するためここには戻らない。
            } catch {
                log.error("self-update failed: \(error.localizedDescription, privacy: .public)")
                showError("更新に失敗しました。\n\(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showInfo(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Snapperkun"
        alert.informativeText = text
        alert.runModal()
    }

    @MainActor
    private func showError(_ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "エラー"
        alert.informativeText = text
        alert.runModal()
    }
}
