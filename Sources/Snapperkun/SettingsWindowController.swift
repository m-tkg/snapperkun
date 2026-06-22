import AppKit
import SwiftUI
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
            let rootView = SettingsView(viewModel: viewModel) { [weak self] in
                self?.window?.close()
            }
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
}
