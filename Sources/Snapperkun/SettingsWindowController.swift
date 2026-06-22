import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SnapperCore

/// 設定ウィンドウ（SwiftUI の SettingsView を NSWindow にホストする）。
/// 表示中は Dock アイコンも出すため、表示/クローズに合わせて activation policy を切り替える。
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let viewModel: SettingsViewModel

    init(initialSettings: SnapperCore.Settings, onApply: @escaping (SnapperCore.Settings) -> Void) {
        self.viewModel = SettingsViewModel(settings: initialSettings, onApply: onApply)
        super.init()
    }

    func show() {
        if window == nil {
            let rootView = SettingsView(
                viewModel: viewModel,
                onClose: { [weak self] in self?.window?.close() },
                onExport: { [weak self] in self?.exportSettings() },
                onImport: { [weak self] in self?.importSettings() }
            )
            let hosting = NSHostingController(rootView: rootView)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Snapperkun 設定"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 600, height: 460))
            window.isReleasedWhenClosed = false
            window.delegate = self
            self.window = window
        }
        // 設定表示中は Dock にも出す。
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // 閉じたらメニューバー常駐のみに戻す（Dock アイコンを隠す）。
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - インポート / エクスポート

    /// 現在の編集内容を JSON ファイルに書き出す。
    private func exportSettings() {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.title = "設定をエクスポート"
        panel.nameFieldStringValue = "snapperkun-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let data = try SettingsCodec.data(from: self.viewModel.settings)
                try data.write(to: url, options: .atomic)
            } catch {
                self.showError("エクスポートに失敗しました。\n\(error.localizedDescription)")
            }
        }
    }

    /// JSON ファイルから設定を読み込み、作業コピーに反映する（確定は Apply/OK）。
    private func importSettings() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.title = "設定をインポート"
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
                self.showError("インポートに失敗しました。設定ファイルを確認してください。\n\(error.localizedDescription)")
            }
        }
    }

    private func showError(_ text: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "エラー"
        alert.informativeText = text
        if let window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }
}
