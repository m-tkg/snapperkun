import XCTest
import CoreGraphics
@testable import SnapperCore

final class SnapCalculatorTests: XCTestCase {
    // 原点を (0,0) 以外にして、minX/minY が正しく加味されるかも検証する。
    private let visible = CGRect(x: 100, y: 50, width: 1200, height: 800)
    // keep 検証用の現在ウィンドウフレーム
    private let current = CGRect(x: 500, y: 250, width: 360, height: 240)

    /// 同一ディスプレイ（source == target）での目標フレーム。
    private func frame(
        _ w: Fraction, _ h: Fraction, _ hr: HorizontalAnchor, _ vr: VerticalAnchor
    ) -> CGRect {
        SnapCalculator.targetFrame(
            currentFrame: current,
            sourceVisibleFrame: visible,
            targetVisibleFrame: visible,
            spec: SnapSpec(width: w, height: h, horizontal: hr, vertical: vr)
        )
    }

    // MARK: - サイズ

    func testFullSizeFillsVisibleFrame() {
        XCTAssertEqual(frame(.full, .full, .left, .top), visible)
    }

    func testHalfWidthHalfHeight() {
        let r = frame(.half, .half, .left, .bottom)
        XCTAssertEqual(r, CGRect(x: 100, y: 50, width: 600, height: 400))
    }

    func testThirdAndQuarterSizes() {
        let third = frame(.oneThird, .oneThird, .left, .bottom)
        XCTAssertEqual(third.width, 400, accuracy: 0.001)
        XCTAssertEqual(third.height, 800.0 / 3.0, accuracy: 0.001)

        let quarter = frame(.oneQuarter, .oneQuarter, .left, .bottom)
        XCTAssertEqual(quarter.width, 300, accuracy: 0.001)
        XCTAssertEqual(quarter.height, 200, accuracy: 0.001)
    }

    // MARK: - 水平アンカー（左半分 / 右半分 / 中央）

    func testLeftHalf() {
        XCTAssertEqual(frame(.half, .full, .left, .top),
                       CGRect(x: 100, y: 50, width: 600, height: 800))
    }

    func testRightHalf() {
        XCTAssertEqual(frame(.half, .full, .right, .top),
                       CGRect(x: 700, y: 50, width: 600, height: 800))
    }

    func testHorizontalCenterHalfWidth() {
        XCTAssertEqual(frame(.half, .full, .center, .top),
                       CGRect(x: 400, y: 50, width: 600, height: 800))
    }

    // MARK: - 垂直アンカー（AppKit: y 上向き）

    func testTopHalfHeight() {
        XCTAssertEqual(frame(.full, .half, .left, .top),
                       CGRect(x: 100, y: 450, width: 1200, height: 400))
    }

    func testBottomHalfHeight() {
        XCTAssertEqual(frame(.full, .half, .left, .bottom),
                       CGRect(x: 100, y: 50, width: 1200, height: 400))
    }

    func testVerticalMiddleHalfHeight() {
        XCTAssertEqual(frame(.full, .half, .left, .middle),
                       CGRect(x: 100, y: 250, width: 1200, height: 400))
    }

    // MARK: - keep（現状維持）

    func testKeepSizeAndPositionIsNoOpOnSameDisplay() {
        // 全項目 keep かつ同一ディスプレイ → 現在フレームのまま
        XCTAssertEqual(frame(.keep, .keep, .keep, .keep), current)
    }

    func testKeepWidthUsesCurrentWidthButAppliesHeightAndAnchor() {
        // 幅は現状維持、高さは半分、左上寄せ
        let r = frame(.keep, .half, .left, .top)
        XCTAssertEqual(r.width, current.width, accuracy: 0.001)   // 幅維持
        XCTAssertEqual(r.minX, visible.minX, accuracy: 0.001)     // 左寄せ
        XCTAssertEqual(r.height, 400, accuracy: 0.001)            // 高さ半分
        XCTAssertEqual(r.maxY, visible.maxY, accuracy: 0.001)     // 上寄せ
    }

    // MARK: - ディスプレイ移動でサイズ維持

    func testMoveToOtherDisplayKeepingSizePreservesRelativePosition() {
        // 移動先ディスプレイ（同サイズ・原点違い）。サイズ・相対位置を維持。
        let target = CGRect(x: 2000, y: 50, width: 1200, height: 800)
        let r = SnapCalculator.targetFrame(
            currentFrame: current,
            sourceVisibleFrame: visible,
            targetVisibleFrame: target,
            spec: SnapSpec(width: .keep, height: .keep, horizontal: .keep, vertical: .keep)
        )
        // サイズは不変
        XCTAssertEqual(r.size, current.size)
        // 元ディスプレイ内の相対中心が移動先でも一致する（原点差 1900 ぶんだけ平行移動）
        XCTAssertEqual(r.midX - target.minX, current.midX - visible.minX, accuracy: 0.001)
        XCTAssertEqual(r.midY - target.minY, current.midY - visible.minY, accuracy: 0.001)
    }

    func testMoveToOtherDisplayKeepSizeWithAnchorPlacesByAnchor() {
        // 移動先で「サイズ維持・左上」: サイズは維持しつつ左上に配置
        let target = CGRect(x: 2000, y: 50, width: 1600, height: 1000)
        let r = SnapCalculator.targetFrame(
            currentFrame: current,
            sourceVisibleFrame: visible,
            targetVisibleFrame: target,
            spec: SnapSpec(width: .keep, height: .keep, horizontal: .left, vertical: .top)
        )
        XCTAssertEqual(r.size, current.size)
        XCTAssertEqual(r.minX, target.minX, accuracy: 0.001)
        XCTAssertEqual(r.maxY, target.maxY, accuracy: 0.001)
    }
}
