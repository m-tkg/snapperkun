import XCTest
import Foundation
@testable import SnapperCore

final class SettingsCodableTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testKeyComboRoundTrip() throws {
        let combo = KeyCombo(keyCode: 123, modifiers: [.command, .option])
        XCTAssertEqual(try roundTrip(combo), combo)
    }

    func testSnapSpecRoundTrip() throws {
        let spec = SnapSpec(width: .twoThirds, height: .full, horizontal: .right, vertical: .middle, display: .next)
        XCTAssertEqual(try roundTrip(spec), spec)
    }

    func testSnapSpecDefaultsToCurrentDisplay() {
        let spec = SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top)
        XCTAssertEqual(spec.display, .current)
    }

    func testSnapSpecDecodesLegacyJSONWithoutDisplay() throws {
        // display キーを持たない旧フォーマットの JSON
        let json = """
        {"width":"half","height":"full","horizontal":"left","vertical":"top"}
        """.data(using: .utf8)!
        let spec = try JSONDecoder().decode(SnapSpec.self, from: json)
        XCTAssertEqual(spec.display, .current)
        XCTAssertEqual(spec.width, .half)
    }

    func testBindingRoundTrip() throws {
        let binding = Binding(
            id: UUID(),
            keyCombo: KeyCombo(keyCode: 124, modifiers: [.control, .option]),
            specs: [
                SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top),
                SnapSpec(width: .twoThirds, height: .full, horizontal: .left, vertical: .top),
            ]
        )
        XCTAssertEqual(try roundTrip(binding), binding)
    }

    func testBindingWithUnassignedKeyComboRoundTrips() throws {
        let binding = Binding(
            id: UUID(),
            keyCombo: nil,
            specs: [SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top)]
        )
        XCTAssertNil(binding.keyCombo)
        XCTAssertEqual(try roundTrip(binding), binding)
    }

    func testNewBindingDefaultsToUnassignedKeyCombo() {
        let binding = Binding(specs: [])
        XCTAssertNil(binding.keyCombo)
    }

    func testSettingsRoundTrip() throws {
        let settings = Settings(bindings: [
            Binding(keyCombo: nil, specs: [
                SnapSpec(width: .half, height: .full, horizontal: .left, vertical: .top),
            ]),
        ])
        XCTAssertEqual(try roundTrip(settings), settings)
    }

    func testEmptySettingsHasNoBindings() {
        XCTAssertTrue(Settings.empty.bindings.isEmpty)
    }
}
