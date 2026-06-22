import CoreGraphics
import Foundation

/// 1 ホットキーに複数の `SnapSpec` を割り当てたときの「押すたびに循環」状態を管理する純粋ロジック。
///
/// 使い方:
///   let i = controller.nextIndex(bindingID:specCount:currentFrame:)  // 適用すべき index
///   ... specs[i] を適用 ...
///   controller.recordApplied(frame: 実際に反映されたフレーム)
public struct RotationController {
    private var lastBindingID: UUID?
    private var lastIndex: Int = 0
    private var lastAppliedFrame: CGRect?
    private let tolerance: CGFloat

    public init(tolerance: CGFloat = 4) {
        self.tolerance = tolerance
    }

    /// 指定ホットキー押下時に適用すべき spec のインデックスを返す。
    /// - 同じホットキーが連続して押され、かつ現在のウィンドウが前回適用フレームと（許容誤差内で）一致 → 次へ進む
    /// - それ以外（別ホットキー / ウィンドウが手動変更された / 初回）→ 先頭に戻る
    public mutating func nextIndex(bindingID: UUID, specCount: Int, currentFrame: CGRect?) -> Int {
        guard specCount > 0 else { return 0 }

        let index: Int
        if bindingID == lastBindingID,
           let last = lastAppliedFrame,
           let current = currentFrame,
           framesMatch(last, current) {
            index = (lastIndex + 1) % specCount
        } else {
            index = 0
        }

        lastBindingID = bindingID
        lastIndex = index
        return index
    }

    /// 実際に反映されたフレームを記録する（次回の一致判定に使う）。
    public mutating func recordApplied(frame: CGRect) {
        lastAppliedFrame = frame
    }

    private func framesMatch(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance &&
        abs(a.minY - b.minY) <= tolerance &&
        abs(a.width - b.width) <= tolerance &&
        abs(a.height - b.height) <= tolerance
    }
}
