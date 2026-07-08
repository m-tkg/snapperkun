import AppKit
import KunAppKit
import SwiftUI
import UniformTypeIdentifiers
import SnapperCore

/// 設定ウィンドウ（SwiftUI の SettingsView を NSWindow にホストする）。
/// 表示中は Dock アイコンも出すため、表示/クローズに合わせて activation policy を切り替える。
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel
    private let loginItem = LoginItemController(
        requiresApprovalMessage: { L.string("login_item.requires_approval") })
    /// ウィンドウ表示時（編集開始）に呼ぶ。グローバルホットキーを停止させる。
    private let onBeginEditing: () -> Void
    /// ウィンドウクローズ時（編集終了）に呼ぶ。グローバルホットキーを再登録させる。
    private let onEndEditing: () -> Void

    init(
        initialSettings: SnapperCore.Settings,
        onApply: @escaping (SnapperCore.Settings) -> Void,
        onBeginEditing: @escaping () -> Void,
        onEndEditing: @escaping () -> Void
    ) {
        self.viewModel = SettingsViewModel(settings: initialSettings, onApply: onApply)
        self.onBeginEditing = onBeginEditing
        self.onEndEditing = onEndEditing
        super.init()
    }

    func show() {
        // 外部（システム設定）で変更された可能性があるため最新状態に同期する。
        loginItem.refresh()
        if window == nil {
            let rootView = SettingsView(
                viewModel: viewModel,
                loginItem: loginItem,
                onClose: { [weak self] in self?.window?.close() },
                onExport: { [weak self] in self?.exportSettings() },
                onImport: { [weak self] in self?.importSettings() }
            )
            let hosting = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hosting)
            window.title = L.string("settings.window.title")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 600, height: 460))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        // 編集中はグローバルホットキーを止める（記録欄でキーを横取りされないため）。
        onBeginEditing()
        // 設定表示中は Dock にも出す。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // 編集終了。停止していたグローバルホットキーを再登録させる。
        onEndEditing()
        // 閉じたらメニューバー常駐のみに戻す（Dock アイコンを隠す）。
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - インポート / エクスポート

    /// 現在の編集内容を JSON ファイルに書き出す。
    private func exportSettings() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.title = L.string("panel.export.title")
        panel.nameFieldStringValue = "snapperkun-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let data = try SettingsCodec.data(from: self.viewModel.settings)
                try data.write(to: url, options: .atomic)
            } catch {
                self.showError(L.format("error.export_failed", error.localizedDescription))
            }
        }
    }

    /// JSON ファイルから設定を読み込み、作業コピーに反映する（確定は Apply/OK）。
    private func importSettings() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = L.string("panel.import.title")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let data = try Data(contentsOf: url)
                let settings = try SettingsCodec.settings(from: data)
                self.viewModel.load(settings)
            } catch {
                self.showError(L.format("error.import_failed", error.localizedDescription))
            }
        }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.string("alert.error.title")
        alert.informativeText = text
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
