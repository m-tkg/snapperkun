import XCTest
@testable import SnapperCore

final class DisplaySelectorTests: XCTestCase {
    func testCurrentReturnsSameIndex() {
        XCTAssertEqual(DisplaySelector.targetIndex(current: 1, count: 3, target: .current), 1)
    }

    func testNextAdvancesAndWraps() {
        XCTAssertEqual(DisplaySelector.targetIndex(current: 0, count: 3, target: .next), 1)
        XCTAssertEqual(DisplaySelector.targetIndex(current: 2, count: 3, target: .next), 0)
    }

    func testPreviousDecrementsAndWraps() {
        XCTAssertEqual(DisplaySelector.targetIndex(current: 2, count: 3, target: .previous), 1)
        XCTAssertEqual(DisplaySelector.targetIndex(current: 0, count: 3, target: .previous), 2)
    }

    func testSingleDisplayAlwaysZero() {
        XCTAssertEqual(DisplaySelector.targetIndex(current: 0, count: 1, target: .next), 0)
        XCTAssertEqual(DisplaySelector.targetIndex(current: 0, count: 1, target: .previous), 0)
    }

    func testZeroCountIsSafe() {
        XCTAssertEqual(DisplaySelector.targetIndex(current: 0, count: 0, target: .next), 0)
    }
}
