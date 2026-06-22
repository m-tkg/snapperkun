import AppKit

// メニューバー常駐アプリとして起動する（Dock アイコンなし）。
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
