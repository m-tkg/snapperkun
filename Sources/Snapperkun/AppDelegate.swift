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
    private var kuntraykunBridge: KuntraykunBridge?
    private var settings = Settings.empty
    /// 設定ウィンドウ表示中は true。グローバルホットキーを一時停止し、
    /// 記録欄（ShortcutRecorderView）が自分自身の登録済みホットキーに
    /// キー入力を横取りされないようにする。
    private var isEditingSettings = false

    private let updateService = UpdateService()
    private lazy var selfUpdater = SelfUpdater(service: updateService)
    private var availableRelease: ReleaseInfo?
    /// 定期サイレントチェック用タイマー。
    private var updateTimer: Timer?
    /// 定期チェック間隔（1時間）。GitHub 未認証 API のレート制限 60回/時 に十分収まる。
    private let updateCheckInterval: TimeInterval = 3600

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

        // kuntraykun 連携: 管理対象なら自分のアイコンを隠し、showMenu でメニューを出す。
        let bridge = KuntraykunBridge(
            setHidden: { [weak self] hidden in self?.statusBar?.setManagedHidden(hidden) },
            popUpMenu: { [weak self] point in self?.statusBar?.popUpMenu(at: point) }
        )
        bridge.start()
        kuntraykunBridge = bridge

        // 起動時にサイレントで更新チェック（あればメニュー文言＋赤バッジを反映）。
        startUpdateCheck(interactive: false)
        startUpdateMonitoring()
    }

    /// 起動時の1回に加え、定期＋スリープ復帰時にもサイレントチェックする。
    /// 結果は集約点 `startUpdateCheck` 経由でメニュー文言と赤バッジへ同期される。
    private func startUpdateMonitoring() {
        // 定期チェック。Timer はメインスレッドで発火するため
        // MainActor.assumeIsolated で @MainActor 隔離の処理を呼ぶ。
        // tolerance を間隔の10%付けて省電力のためコアレッシングを許可する。
        let timer = Timer.scheduledTimer(
            withTimeInterval: updateCheckInterval, repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startUpdateCheck(interactive: false)
            }
        }
        timer.tolerance = updateCheckInterval * 0.1
        updateTimer = timer

        // Timer はスリープ中に発火しないため、復帰時にも即チェックする
        // （ノート PC で「閉じている間に新版」に対応）。
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.startUpdateCheck(interactive: false)
            }
        }
    }

    private func reloadHotkeys() {
        // 設定編集中はホットキーを止めたままにする（記録欄でキーを横取りしないため）。
        // Apply 中も再登録せず、ウィンドウを閉じたタイミングでまとめて登録し直す。
        guard !isEditingSettings else {
            log.info("reloadHotkeys: suspended (editing settings)")
            hotkeyManager.unregisterAll()
            return
        }
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
                },
                onBeginEditing: { [weak self] in
                    guard let self else { return }
                    self.isEditingSettings = true
                    self.reloadHotkeys()
                },
                onEndEditing: { [weak self] in
                    guard let self else { return }
                    self.isEditingSettings = false
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
                // kuntraykun にもアップデート有無を伝える（集約バッジ/赤丸用）。
                kuntraykunBridge?.reportUpdate(isNewer)
                if interactive {
                    if isNewer {
                        promptInstall(release)
                    } else {
                        showInfo(L.format("update.latest", UpdateService.currentVersion))
                    }
                }
            } catch {
                log.error("update check failed: \(error.localizedDescription, privacy: .public)")
                if interactive {
                    showError(L.format("update.check_failed", error.localizedDescription))
                }
            }
        }
    }

    @MainActor
    private func promptInstall(_ release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L.format("update.available.title", release.tagName)
        alert.informativeText = L.format("update.available.body", UpdateService.currentVersion)
        alert.addButton(withTitle: L.string("update.button.update"))
        alert.addButton(withTitle: L.string("update.button.open_release"))
        alert.addButton(withTitle: L.string("button.cancel"))
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
                showError(L.format("update.failed", error.localizedDescription))
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
        alert.messageText = L.string("alert.error.title")
        alert.informativeText = text
        alert.runModal()
    }
}
