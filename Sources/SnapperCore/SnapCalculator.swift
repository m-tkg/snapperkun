import CoreGraphics

/// 現在フレーム・移動元/移動先の `visibleFrame`（いずれも AppKit 座標, y 上向き）と
/// `SnapSpec` から、移動先ディスプレイ上での目標フレーム（AppKit 座標）を算出する純粋関数。
///
/// 各軸は独立に扱う:
/// - サイズ: `Fraction.keep` なら現在のサイズを維持、それ以外は `targetVisibleFrame * 倍率`。
/// - 位置: アンカーが `keep` なら、移動元 visibleFrame 内での相対中心を移動先へ写して維持。
///   それ以外は移動先 visibleFrame に対して左/中央/右・上/中央/下へ寄せる。
///
/// 同一ディスプレイでは `sourceVisibleFrame == targetVisibleFrame` を渡す。
public enum SnapCalculator {
    public static func targetFrame(
        currentFrame: CGRect,
        sourceVisibleFrame: CGRect,
        targetVisibleFrame: CGRect,
        spec: SnapSpec
    ) -> CGRect {
        let width = spec.width.isKeep
            ? currentFrame.width
            : targetVisibleFrame.width * spec.width.value
        let height = spec.height.isKeep
            ? currentFrame.height
            : targetVisibleFrame.height * spec.height.value

        let x: CGFloat
        switch spec.horizontal {
        case .keep:
            // 移動元での相対中心を移動先へ写す。
            let relativeCenter = (currentFrame.midX - sourceVisibleFrame.minX) / sourceVisibleFrame.width
            x = targetVisibleFrame.minX + relativeCenter * targetVisibleFrame.width - width / 2
        case .left:
            x = targetVisibleFrame.minX
        case .center:
            x = targetVisibleFrame.minX + (targetVisibleFrame.width - width) / 2
        case .right:
            x = targetVisibleFrame.maxX - width
        }

        // AppKit 座標系（y 上向き）。top は最大 y 側、bottom は最小 y 側に寄せる。
        let y: CGFloat
        switch spec.vertical {
        case .keep:
            let relativeCenter = (currentFrame.midY - sourceVisibleFrame.minY) / sourceVisibleFrame.height
            y = targetVisibleFrame.minY + relativeCenter * targetVisibleFrame.height - height / 2
        case .top:
            y = targetVisibleFrame.maxY - height
        case .middle:
            y = targetVisibleFrame.minY + (targetVisibleFrame.height - height) / 2
        case .bottom:
            y = targetVisibleFrame.minY
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }
}
