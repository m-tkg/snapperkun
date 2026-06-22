import XCTest
import Foundation
@testable import SnapperCore

final class SettingsCodecTests: XCTestCase {
    private let sample = Settings(bindings: [
        Binding(
            keyCombo: KeyCombo(keyCode: 124, modifiers: [.control, .option]),
            specs: [
                SnapSpec(width: .half, height: .full, horizontal: .right, vertical: .top),
                SnapSpec(width: .keep, height: .keep, horizontal: .keep, vertical: .keep, display: .next),
            ]
        )
    ])

    func testEncodeThenDecodeRoundTrips() throws {
        let data = try SettingsCodec.data(from: sample)
        let decoded = try SettingsCodec.settings(from: data)
        XCTAssertEqual(decoded, sample)
    }

    func testEncodedDataIsReadableJSON() throws {
        let data = try SettingsCodec.data(from: sample)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("bindings"))
        // pretty-printed（改行あり）であること
        XCTAssertTrue(text.contains("\n"))
    }

    func testDecodeInvalidDataThrows() {
        let invalid = Data("not json".utf8)
        XCTAssertThrowsError(try SettingsCodec.settings(from: invalid))
    }
}
