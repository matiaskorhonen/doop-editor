import XCTest
@testable import CodeEditTextView

final class TypesetterBenchTests: XCTestCase {
    func test_wrapLongUnbreakableLine() {
        // Simulates a single huge base64-encoded line: no whitespace/punctuation, so word-wrap
        // must fall through the "walk back up to 100 chars" search on every fragment.
        let string = String(repeating: "a", count: 400_000)
        let typesetter = Typesetter()
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)]

        let start = Date()
        typesetter.typeset(
            NSAttributedString(string: string, attributes: attributes),
            documentRange: NSRange(location: 0, length: string.count),
            displayData: TextLine.DisplayData(
                maxWidth: 400.0,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word
            ),
            markedRanges: nil
        )
        let elapsed = Date().timeIntervalSince(start)
        // Regression guard for a hang caused by `CharacterSet(charactersIn:).isSubset(of:)` allocating and
        // intersecting a set per character while searching for a break; on this input it took ~2.5s before
        // being replaced with a direct scalar membership check (~0.2s). 1s leaves comfortable CI headroom.
        XCTAssertLessThan(elapsed, 1.0)
        XCTAssertGreaterThan(typesetter.lineFragments.count, 0)
    }
}
