import AppKit
import CoreImage

/// メニューバー常駐アイコンとメニューを管理する。
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    /// ステータスメニュー本体。kuntraykun 連携時はこのメニューを指定座標へ popUp する。
    private let menu = NSMenu()
    private let openSettings: () -> Void
    private let checkPermission: () -> Void
    private let checkForUpdate: () -> Void
    private let quitApp: () -> Void
    private var updateItem: NSMenuItem!
    /// 新バージョンがあるときにメニューバーアイコン右下へ重ねる赤バッジ。
    private var badgeView: NSView!

    private static var checkUpdateTitle: String { L.string("menu.check_update") }

    /// ローカル検証ビルド（バンドル ID が `.local` で終わる）かどうか。
    private var isLocalBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".local")
    }

    init(
        openSettings: @escaping () -> Void,
        checkPermission: @escaping () -> Void,
        checkForUpdate: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.openSettings = openSettings
        self.checkPermission = checkPermission
        self.checkForUpdate = checkForUpdate
        self.quitApp = quit
        super.init()

        if let button = statusItem.button {
            if let template = Self.menuBarImage() {
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
            // ローカルビルドは「ローカル」を併記して本番と区別する。
            if isLocalBuild {
                button.title = " " + L.string("menu_bar.local")
                button.imagePosition = .imageLeading
            }
            setupBadge(on: button)
        }
        // kuntraykun 一覧用に、現在のメニューバーアイコンを共有場所へ書き出す（連携 v2）。
        KuntraykunIconExport.export(statusItem.button?.image)

        // 先頭にバージョン情報（操作不可）。ローカルビルドは併記する。
        var versionTitle = L.format("menu.version", UpdateService.currentVersion)
        if isLocalBuild { versionTitle += " (" + L.string("menu_bar.local") + ")" }
        let versionItem = NSMenuItem(title: versionTitle, action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(title: L.string("menu.settings"), action: #selector(handleOpenSettings), key: ","))
        menu.addItem(menuItem(title: L.string("menu.check_permission"), action: #selector(handleCheckPermission), key: ""))
        updateItem = menuItem(title: Self.checkUpdateTitle, action: #selector(handleCheckForUpdate), key: "")
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(menuItem(title: L.string("menu.quit"), action: #selector(handleQuit), key: "q"))
        statusItem.menu = menu
    }

    /// 新バージョンが利用可能なときにメニュー文言を変更し、赤バッジを表示する。
    func setUpdateAvailable(tag: String) {
        updateItem.title = L.format("menu.install_update", tag)
        badgeView?.isHidden = false
        // メニュー文言が変わったので kuntraykun 用スナップショットを書き出し直す（連携 v4）。
        exportMenuSnapshot()
    }

    /// 最新（更新なし）状態に戻し、赤バッジを消す。
    func clearUpdateAvailable() {
        updateItem.title = Self.checkUpdateTitle
        badgeView?.isHidden = true
        exportMenuSnapshot()
    }

    /// アイコン右下に重ねる赤バッジ（小さな赤丸）を構成する。
    /// ベースアイコンは template のまま維持し、色付きの丸は別 view として
    /// オーバーレイする（画像へ焼き込むとメニューバーの自動着色が壊れるため）。
    /// 位置は trailing ではなく **アイコン画像の幅基準** で右下に固定するので、
    /// ローカルビルドで「ローカル」を併記（`imagePosition = .imageLeading`）しても
    /// 常にアイコングリフの右下に乗る。
    /// 注意: kuntraykun に集約されてアイコンを隠している間（`setManagedHidden(true)`）は
    /// アイコンごと非表示になるためバッジも見えない（集約先への伝搬は対象外）。
    private func setupBadge(on button: NSStatusBarButton) {
        let badgeSize: CGFloat = 7
        // アイコングリフの幅。テキスト併記時でも画像自身の幅を基準にする。
        let iconWidth = button.image?.size.width ?? badgeSize

        let badge = NSView()
        badge.wantsLayer = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        if let layer = badge.layer {
            layer.backgroundColor = NSColor.systemRed.cgColor
            layer.cornerRadius = badgeSize / 2
            // メニューバー背景に溶けないよう細い白の縁取りを付ける。
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.cgColor
        }
        badge.isHidden = true
        badge.toolTip = L.string("badge.update_available")
        badge.setAccessibilityLabel(L.string("badge.update_available"))

        button.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: badgeSize),
            badge.heightAnchor.constraint(equalToConstant: badgeSize),
            badge.leadingAnchor.constraint(
                equalTo: button.leadingAnchor, constant: iconWidth - badgeSize),
            badge.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])
        badgeView = badge
    }

    // MARK: - kuntraykun 連携

    /// kuntraykun に集約されている間、自分のメニューバーアイコンを隠す/戻す。
    func setManagedHidden(_ hidden: Bool) {
        statusItem.isVisible = !hidden
    }

    /// 自分のステータスメニューを指定スクリーン座標（左下原点）に表示する。
    func popUpMenu(at point: NSPoint) {
        menu.popUp(positioning: nil, at: point, in: nil)
    }

    /// メニュー構造を kuntraykun 用の共有場所へ書き出す（連携 v4）。
    /// 起動時・requestMenu 受信時・メニュー内容が変わる箇所から呼ぶ。
    func exportMenuSnapshot() {
        KuntraykunMenuExport.export(menu)
    }

    /// kuntraykun のサブメニューでクリックされた項目（インデックスパス ID）を実行する（連携 v4）。
    func performMenuItem(id: String) -> Bool {
        KuntraykunMenuExport.performItem(id: id, in: menu)
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

    @objc private func handleCheckForUpdate() {
        checkForUpdate()
    }

    @objc private func handleQuit() {
        quitApp()
    }

    /// メニューバーに表示するテンプレート画像を返す。
    /// 専用画像（Resources/MenuBarIcon.png）があれば優先し、無ければアプリアイコンから生成する。
    private static func menuBarImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url),
           let template = makeTemplateIcon(from: image) {
            return template
        }
        return makeTemplateIcon(from: NSApp.applicationIconImage)
    }

    /// 画像から、メニューバー用のモノクロ（テンプレート）画像を生成する。
    /// 「図柄部分のアルファ」をそのまま使い、RGB を 0（黒）にする。
    /// テンプレート画像として、メニューバーの明暗に応じて黒/白に着色される。
    /// 失敗時は nil。
    private static func makeTemplateIcon(from source: NSImage?, height: CGFloat = 18) -> NSImage? {
        guard let source,
              let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let ciImage = CIImage(cgImage: cgImage)

        // RGB を 0（黒）に、アルファは元画像のアルファをそのまま使う。
        guard let filter = CIFilter(name: "CIColorMatrix") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        filter.setValue(zero, forKey: "inputRVector")
        filter.setValue(zero, forKey: "inputGVector")
        filter.setValue(zero, forKey: "inputBVector")
        // アルファ = 元画像のアルファ
        filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        filter.setValue(zero, forKey: "inputBiasVector")

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
