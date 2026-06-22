import XCTest
import CoreGraphics
@testable import SnapperCore

final class RotationControllerTests: XCTestCase {
    private let bindingA = UUID()
    private let bindingB = UUID()
    private let frame1 = CGRect(x: 0, y: 0, width: 600, height: 800)

    func testFirstPressReturnsZero() {
        var c = RotationController()
        XCTAssertEqual(c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nil), 0)
    }

    func testRepeatedPressAdvancesWhenWindowMatchesLastApplied() {
        var c = RotationController()
        let i0 = c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nil)
        c.recordApplied(frame: frame1)
        XCTAssertEqual(i0, 0)

        // ウィンドウが前回適用フレームのまま → 次へ進む
        let i1 = c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: frame1)
        XCTAssertEqual(i1, 1)
    }

    func testRotationWrapsAround() {
        var c = RotationController()
        _ = c.nextIndex(bindingID: bindingA, specCount: 2, currentFrame: nil)
        c.recordApplied(frame: frame1)
        let i1 = c.nextIndex(bindingID: bindingA, specCount: 2, currentFrame: frame1)
        c.recordApplied(frame: frame1)
        XCTAssertEqual(i1, 1)
        // 2 個しかないので次は 0 に戻る
        let i2 = c.nextIndex(bindingID: bindingA, specCount: 2, currentFrame: frame1)
        XCTAssertEqual(i2, 0)
    }

    func testDifferentBindingResetsToZero() {
        var c = RotationController()
        _ = c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nil)
        c.recordApplied(frame: frame1)
        // 別ホットキー → 0 から
        XCTAssertEqual(c.nextIndex(bindingID: bindingB, specCount: 3, currentFrame: frame1), 0)
    }

    func testManuallyMovedWindowResetsToZero() {
        var c = RotationController()
        _ = c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nil)
        c.recordApplied(frame: frame1)
        // ユーザーが動かした → 前回適用フレームと一致しない → 0 から
        let moved = CGRect(x: 300, y: 0, width: 600, height: 800)
        XCTAssertEqual(c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: moved), 0)
    }

    func testMatchWithinToleranceStillAdvances() {
        var c = RotationController(tolerance: 4)
        _ = c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nil)
        c.recordApplied(frame: frame1)
        // 許容誤差内のズレ（アプリがグリッドに丸めた等）→ 進む
        let nearlySame = CGRect(x: 2, y: 1, width: 598, height: 803)
        XCTAssertEqual(c.nextIndex(bindingID: bindingA, specCount: 3, currentFrame: nearlySame), 1)
    }

    func testSingleSpecAlwaysZero() {
        var c = RotationController()
        _ = c.nextIndex(bindingID: bindingA, specCount: 1, currentFrame: nil)
        c.recordApplied(frame: frame1)
        XCTAssertEqual(c.nextIndex(bindingID: bindingA, specCount: 1, currentFrame: frame1), 0)
    }
}
