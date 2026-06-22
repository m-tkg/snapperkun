import XCTest
@testable import SnapperCore

final class VersionComparatorTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertTrue(VersionComparator.isNewer(tag: "v1.0.1", than: "1.0.0"))
    }

    func testSameVersionIsNotNewer() {
        XCTAssertFalse(VersionComparator.isNewer(tag: "v1.0.0", than: "1.0.0"))
        XCTAssertFalse(VersionComparator.isNewer(tag: "1.0.0", than: "1.0.0"))
    }

    func testOlderIsNotNewer() {
        XCTAssertFalse(VersionComparator.isNewer(tag: "v1.0.0", than: "1.0.1"))
    }

    func testNumericComponentComparisonNotLexicographic() {
        // 1.10.0 は 1.2.0 より新しい
        XCTAssertTrue(VersionComparator.isNewer(tag: "v1.10.0", than: "1.2.0"))
        XCTAssertFalse(VersionComparator.isNewer(tag: "v1.2.0", than: "1.10.0"))
    }

    func testDifferentComponentCounts() {
        XCTAssertTrue(VersionComparator.isNewer(tag: "v2.0", than: "1.9.9"))
        XCTAssertFalse(VersionComparator.isNewer(tag: "v1.0", than: "1.0.0"))
    }

    func testPrereleaseSuffixIgnored() {
        XCTAssertFalse(VersionComparator.isNewer(tag: "v1.0.0-beta", than: "1.0.0"))
        XCTAssertTrue(VersionComparator.isNewer(tag: "v1.1.0-beta", than: "1.0.0"))
    }

    func testReleaseInfoDecodesGitHubKeys() throws {
        let json = """
        {"tag_name":"v1.2.3","html_url":"https://example.com/r","extra":1}
        """.data(using: .utf8)!
        let info = try JSONDecoder().decode(ReleaseInfo.self, from: json)
        XCTAssertEqual(info.tagName, "v1.2.3")
        XCTAssertEqual(info.htmlUrl, "https://example.com/r")
    }
}
