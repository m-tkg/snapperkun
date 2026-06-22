import AppKit

// メニューバー常駐アプリとして起動する（Dock アイコンなし）。
// トップレベルはメインスレッドで実行されるため、MainActor として扱う。
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
