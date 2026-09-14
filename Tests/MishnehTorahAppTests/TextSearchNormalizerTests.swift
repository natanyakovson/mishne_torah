import XCTest
@testable import MishnehTorahApp

final class TextSearchNormalizerTests: XCTestCase {
    func testHebrewSearchIgnoresNiqqud() {
        XCTAssertTrue(TextSearchNormalizer.contains("יְסוֹד הַיְסוֹדוֹת", query: "יסוד"))
    }

    func testHebrewRangesMapBackToOriginalTextWithNiqqud() {
        let text = "יְסוֹד הַיְסוֹדוֹת"
        let ranges = TextSearchNormalizer.ranges(in: text, matching: "יסוד")

        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(String(text[ranges[0]]), "יְסוֹד")
    }

    func testRussianSearchIgnoresCase() {
        XCTAssertTrue(TextSearchNormalizer.contains("Моше бен Маймон", query: "моше"))
    }
}
