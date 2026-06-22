import AppKit
import OSLog
import SnapperCore

private let log = Logger(subsystem: "com.mtkg.snapperkun", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore(url: SettingsStore.defaultURL())
    private let hotkeyManager = HotkeyManager()
    private let engine = SnapEngine()
    private var statusBar: StatusBarController?
    private var settingsWindowController: SettingsWindowController?
    private var settings = Settings.empty

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ウィンドウ操作に必要なアクセシビリティ権限を要求する。
        AccessibilityPermission.requestIfNeeded()

        settings = store.load()

        statusBar = StatusBarController(
            openSettings: { [weak self] in self?.openSettings() },
            checkPermission: { AccessibilityPermission.requestIfNeeded() },
            quit: { NSApp.terminate(nil) }
        )

        reloadHotkeys()
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
                onChange: { [weak self] newSettings in
                    guard let self else { return }
                    self.settings = newSettings
                    try? self.store.save(newSettings)
                    self.reloadHotkeys()
                }
            )
        }
        settingsWindowController?.show()
    }
}
