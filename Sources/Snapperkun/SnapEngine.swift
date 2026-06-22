import AppKit
import SnapperCore

/// ホットキー押下を受けて、アクティブウィンドウへスナップを適用する。
/// WindowManager（AX）と RotationController（循環状態）を仲介する。
final class SnapEngine {
    private let windowManager = WindowManager()
    private var rotation = RotationController()

    /// 指定 Binding を処理する。メインスレッドで呼ぶこと。
    func handle(binding: Binding) {
        guard !binding.specs.isEmpty else { return }
        guard let window = windowManager.focusedWindow() else {
            NSSound.beep()
            return
        }
        let current = windowManager.currentFrameAppKit(of: window)
        let index = rotation.nextIndex(
            bindingID: binding.id,
            specCount: binding.specs.count,
            currentFrame: current
        )
        if let applied = windowManager.apply(spec: binding.specs[index], to: window) {
            rotation.recordApplied(frame: applied)
        }
    }
}
