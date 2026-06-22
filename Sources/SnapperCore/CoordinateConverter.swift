import CoreGraphics

/// AppKit 座標（原点=メインディスプレイ左下, y 上向き）と
/// Quartz/AX グローバル座標（原点=メインディスプレイ左上, y 下向き）の相互変換。
///
/// `primaryHeight` はメインディスプレイ（メニューバーのある画面）の高さ。
public enum CoordinateConverter {
    /// AppKit の矩形を CG/AX の矩形（top-left 原点）に変換する。
    public static func appKitToCGTopLeft(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// CG/AX の矩形（top-left 原点）を AppKit の矩形に変換する。
    public static func cgTopLeftToAppKit(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - (rect.minY + rect.height), width: rect.width, height: rect.height)
    }
}
