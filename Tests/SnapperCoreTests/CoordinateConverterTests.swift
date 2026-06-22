import XCTest
import CoreGraphics
@testable import SnapperCore

final class CoordinateConverterTests: XCTestCase {
    private let primaryHeight: CGFloat = 1000

    func testAppKitBottomLeftConvertsToCGTopLeft() {
        // AppKit: 原点左下。高さ 1000 の画面で、下端から y=200 にある高さ300のウィンドウ。
        let appKit = CGRect(x: 100, y: 200, width: 400, height: 300)
        let cg = CoordinateConverter.appKitToCGTopLeft(appKit, primaryHeight: primaryHeight)
        // CG の top-left y = 1000 - (200 + 300) = 500、x はそのまま
        XCTAssertEqual(cg, CGRect(x: 100, y: 500, width: 400, height: 300))
    }

    func testRoundTripIsIdentity() {
        let appKit = CGRect(x: 12, y: 34, width: 567, height: 89)
        let cg = CoordinateConverter.appKitToCGTopLeft(appKit, primaryHeight: primaryHeight)
        let back = CoordinateConverter.cgTopLeftToAppKit(cg, primaryHeight: primaryHeight)
        XCTAssertEqual(back, appKit)
    }

    func testFullScreenStaysAtOrigin() {
        let appKit = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let cg = CoordinateConverter.appKitToCGTopLeft(appKit, primaryHeight: primaryHeight)
        XCTAssertEqual(cg, CGRect(x: 0, y: 0, width: 1600, height: 1000))
    }
}
