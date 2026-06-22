import AppKit
import CoreImage

/// メニューバー常駐アイコンとメニューを管理する。
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let openSettings: () -> Void
    private let checkPermission: () -> Void
    private let quitApp: () -> Void

    init(
        openSettings: @escaping () -> Void,
        checkPermission: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.openSettings = openSettings
        self.checkPermission = checkPermission
        self.quitApp = quit
        super.init()

        if let button = statusItem.button {
            // アプリアイコンのモノクロ（テンプレート）版をメニューバーアイコンに使う。
            if let template = Self.makeTemplateIcon(from: NSApp.applicationIconImage) {
                button.image = template
            } else {
                button.image = NSImage(
                    systemSymbolName: "rectangle.split.2x1",
                    accessibilityDescription: "Snapperkun"
                )
                if button.image == nil {
                    button.title = "▱"
                }
            }
        }

        let menu = NSMenu()
        menu.addItem(menuItem(title: "設定…", action: #selector(handleOpenSettings), key: ","))
        menu.addItem(menuItem(title: "アクセシビリティ権限を確認", action: #selector(handleCheckPermission), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Snapperkun を終了", action: #selector(handleQuit), key: "q"))
        statusItem.menu = menu
    }

    private func menuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    @objc private func handleCheckPermission() {
        checkPermission()
    }

    @objc private func handleQuit() {
        quitApp()
    }

    /// アプリアイコンから、メニューバー用のモノクロ（テンプレート）画像を生成する。
    /// 黒一色にし、元画像の「暗さ」をアルファに写す（明るい背景は透明、図柄は不透明）。
    /// 失敗時は nil。
    private static func makeTemplateIcon(from source: NSImage?, height: CGFloat = 18) -> NSImage? {
        guard let source,
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)

        // RGB を 0（黒）に、アルファ = 1 - 輝度 に変換する。
        guard let filter = CIFilter(name: "CIColorMatrix") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.setValue(zero, forKey: "inputRVector")
        filter.setValue(zero, forKey: "inputGVector")
        filter.setValue(zero, forKey: "inputBVector")
        // アルファ = -(0.299R + 0.587G + 0.114B) + 1
        filter.setValue(CIVector(x: -0.299, y: -0.587, z: -0.114, w: 0), forKey: "inputAVector")
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBiasVector")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        // バイアスでアルファが全平面に乗り output.extent が無限大になるため、
        // 元画像の有限 extent でクロップして取り出す。
        let bounds = ciImage.extent
        guard let resultCG = context.createCGImage(output, from: bounds) else { return nil }

        let aspect = bounds.height > 0 ? bounds.width / bounds.height : 1
        let size = NSSize(width: height * aspect, height: height)
        let image = NSImage(cgImage: resultCG, size: size)
        image.isTemplate = true
        return image
    }
}
