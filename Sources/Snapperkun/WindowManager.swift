import AppKit
import ApplicationServices
import SnapperCore

/// アクティブウィンドウの取得・移動・リサイズを Accessibility API 経由で行う。
/// 内部処理は AppKit 座標で行い、AX へのアクセス時にのみ CG 座標へ変換する。
final class WindowManager {

    /// メインディスプレイ（メニューバーのある画面）の高さ。座標変換の基準。
    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    /// フロントモストアプリのフォーカスウィンドウを返す。
    func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowRef
        )
        guard result == .success, let windowRef,
              CFGetTypeID(windowRef) == AXUIElementGetTypeID() else { return nil }
        return (windowRef as! AXUIElement)
    }

    /// 指定ウィンドウの現在フレームを AppKit 座標で返す。
    func currentFrameAppKit(of window: AXUIElement) -> CGRect? {
        guard let position = copyPosition(of: window), let size = copySize(of: window) else {
            return nil
        }
        let cgRect = CGRect(origin: position, size: size)
        return CoordinateConverter.cgTopLeftToAppKit(cgRect, primaryHeight: Self.primaryHeight)
    }

    /// spec を適用し、実際に反映されたフレーム（AppKit 座標）を返す。失敗時は nil。
    @discardableResult
    func apply(spec: SnapSpec, to window: AXUIElement) -> CGRect? {
        guard let current = currentFrameAppKit(of: window) else { return nil }

        // spec.display に応じて適用先スクリーンを選ぶ。
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }
        let currentIndex = Self.indexOfScreen(containing: current, in: screens) ?? 0
        let targetIndex = DisplaySelector.targetIndex(
            current: currentIndex,
            count: screens.count,
            target: spec.display
        )
        let sourceVisibleFrame = screens[currentIndex].visibleFrame
        let targetVisibleFrame = screens[targetIndex].visibleFrame

        let target = SnapCalculator.targetFrame(
            currentFrame: current,
            sourceVisibleFrame: sourceVisibleFrame,
            targetVisibleFrame: targetVisibleFrame,
            spec: spec
        )
        setFrame(target, to: window)
        // アプリ側がサイズを丸める場合があるため、適用後の実フレームを返す。
        return currentFrameAppKit(of: window)
    }

    // MARK: - AX 読み書き

    private func setFrame(_ appKitRect: CGRect, to window: AXUIElement) {
        let cg = CoordinateConverter.appKitToCGTopLeft(appKitRect, primaryHeight: Self.primaryHeight)
        var position = cg.origin
        var size = cg.size

        // サイズ → 位置 → サイズ の順に設定すると、最小サイズ制約による取りこぼしを減らせる。
        setSize(&size, to: window)
        setPosition(&position, to: window)
        setSize(&size, to: window)
    }

    private func setPosition(_ point: inout CGPoint, to window: AXUIElement) {
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        }
    }

    private func setSize(_ size: inout CGSize, to window: AXUIElement) {
        if let value = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        }
    }

    private func copyPosition(of window: AXUIElement) -> CGPoint? {
        guard let value = copyAXValue(window, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func copySize(of window: AXUIElement) -> CGSize? {
        guard let value = copyAXValue(window, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private func copyAXValue(_ window: AXUIElement, _ attribute: String) -> AXValue? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        return (ref as! AXValue)
    }

    // MARK: - スクリーン判定

    /// AppKit 座標の矩形の中心を含むスクリーンの index を返す。
    private static func indexOfScreen(containing rect: CGRect, in screens: [NSScreen]) -> Int? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return screens.firstIndex { $0.frame.contains(center) }
    }
}
