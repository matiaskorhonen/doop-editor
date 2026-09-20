import XCTest
@testable import DoopEditor

final class DemoTextAttachment: TextAttachment {
    var width: CGFloat
    var isSelected: Bool = false

    init(width: CGFloat = 100) {
        self.width = width
    }

    func draw(in context: CGContext, rect: NSRect) {
        context.saveGState()
        context.setFillColor(NSColor.red.cgColor)
        context.fill(rect)
        context.restoreGState()
    }
}

class TypesetterTests: XCTestCase {
    // NOTE: makes chars that are ~6.18 pts wide
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)]
    var typesetter: Typesetter!

    override func setUp() {
        typesetter = Typesetter()
        continueAfterFailure = false
    }

    func test_LineFeedBreak() {
        typesetter.typeset(
            NSAttributedString(string: "testline\n"),
            documentRange: NSRange(location: 0, length: 9),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")

        typesetter.typeset(
            NSAttributedString(string: "testline\n"),
            documentRange: NSRange(location: 0, length: 9),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")
    }

    func test_carriageReturnBreak() {
        typesetter.typeset(
            NSAttributedString(string: "testline\r"),
            documentRange: NSRange(location: 0, length: 9),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")

        typesetter.typeset(
            NSAttributedString(string: "testline\r"),
            documentRange: NSRange(location: 0, length: 9),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")
    }

    func test_carriageReturnLineFeedBreak() {
        typesetter.typeset(
            NSAttributedString(string: "testline\r\n"),
            documentRange: NSRange(location: 0, length: 10),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")

        typesetter.typeset(
            NSAttributedString(string: "testline\r\n"),
            documentRange: NSRange(location: 0, length: 10),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1, "Typesetter typeset incorrect number of lines.")
    }

    func test_wrapLinesReturnsValidFragmentRanges() throws {
        // Ensure that when wrapping, each wrapped line fragment has correct ranges.
        typesetter.typeset(
            NSAttributedString(string: String(repeating: "A", count: 1000), attributes: attributes),
            documentRange: NSRange(location: 0, length: 1000),
            displayData: TextLine.DisplayData(
                maxWidth: 150,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil,
            attachments: []
        )

        let firstFragment = try XCTUnwrap(typesetter.lineFragments.first)

        for fragment in typesetter.lineFragments {
            // The end of the fragment shouldn't extend beyond the valid document range
            XCTAssertLessThanOrEqual(fragment.range.max, 1000)
            // Because we're breaking on characters, and filling each line with the same char
            // Each fragment should be as long or shorter than the first fragment.
            XCTAssertLessThanOrEqual(fragment.range.length, firstFragment.range.length)
        }
    }

    // MARK: - Attachments

    func test_layoutSingleFragmentWithAttachment() throws {
        let attachment = DemoTextAttachment()
        typesetter.typeset(
            NSAttributedString(string: "ABC"),
            documentRange: NSRange(location: 0, length: 3),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil,
            attachments: [AnyTextAttachment(range: NSRange(location: 1, length: 1), attachment: attachment)]
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1)
        let fragment = try XCTUnwrap(typesetter.lineFragments.first?.data)
        XCTAssertEqual(fragment.contents.count, 3)
        XCTAssertTrue(fragment.contents[0].isText)
        XCTAssertFalse(fragment.contents[1].isText)
        XCTAssertTrue(fragment.contents[2].isText)
        XCTAssertEqual(
            fragment.contents[1],
            .init(
                data: .attachment(attachment: .init(range: NSRange(location: 1, length: 1), attachment: attachment)),
                width: attachment.width
            )
        )
    }

    func test_layoutSingleFragmentEntirelyAttachment() throws {
        let attachment = DemoTextAttachment()
        typesetter.typeset(
            NSAttributedString(string: "ABC"),
            documentRange: NSRange(location: 0, length: 3),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil,
            attachments: [AnyTextAttachment(range: NSRange(location: 0, length: 3), attachment: attachment)]
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1)
        let fragment = try XCTUnwrap(typesetter.lineFragments.first?.data)
        XCTAssertEqual(fragment.contents.count, 1)
        XCTAssertFalse(fragment.contents[0].isText)
        XCTAssertEqual(
            fragment.contents[0],
            .init(
                data: .attachment(attachment: .init(range: NSRange(location: 0, length: 3), attachment: attachment)),
                width: attachment.width
            )
        )
    }

    func test_wrapLinesWithAttachment() throws {
        let attachment = DemoTextAttachment(width: 130)

        // Total should be slightly > 160px, breaking off 2 and 3
        typesetter.typeset(
            NSAttributedString(string: "ABC123", attributes: attributes),
            documentRange: NSRange(location: 0, length: 6),
            displayData: TextLine.DisplayData(
                maxWidth: 150,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil,
            attachments: [.init(range: NSRange(location: 1, length: 1), attachment: attachment)]
        )

        XCTAssertEqual(typesetter.lineFragments.count, 2)

        var fragment = try XCTUnwrap(typesetter.lineFragments.first?.data)
        XCTAssertEqual(fragment.contents.count, 3) // First fragment includes the attachment and characters after
        XCTAssertTrue(fragment.contents[0].isText)
        XCTAssertFalse(fragment.contents[1].isText)
        XCTAssertTrue(fragment.contents[2].isText)

        fragment = try XCTUnwrap(typesetter.lineFragments.getLine(atIndex: 1)?.data)
        XCTAssertEqual(fragment.contents.count, 1) // Second fragment is only text
        XCTAssertTrue(fragment.contents[0].isText)
    }

    func test_wrapLinesWithWideAttachment() throws {
        // Attachment takes up more than the available room.
        // Expected result: attachment is on it's own line fragment with no other text.
        let attachment = DemoTextAttachment(width: 150)

        typesetter.typeset(
            NSAttributedString(string: "ABC123", attributes: attributes),
            documentRange: NSRange(location: 0, length: 6),
            displayData: TextLine.DisplayData(
                maxWidth: 150,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .character
            ),
            markedRanges: nil,
            attachments: [.init(range: NSRange(location: 1, length: 1), attachment: attachment)]
        )

        XCTAssertEqual(typesetter.lineFragments.count, 3)

        var fragment = try XCTUnwrap(typesetter.lineFragments.first?.data)
        XCTAssertEqual(fragment.contents.count, 1)
        XCTAssertTrue(fragment.contents[0].isText)

        fragment = try XCTUnwrap(typesetter.lineFragments.getLine(atIndex: 1)?.data)
        XCTAssertEqual(fragment.contents.count, 1)
        XCTAssertFalse(fragment.contents[0].isText)

        fragment = try XCTUnwrap(typesetter.lineFragments.getLine(atIndex: 2)?.data)
        XCTAssertEqual(fragment.contents.count, 1)
        XCTAssertTrue(fragment.contents[0].isText)
    }

    func test_wrapLinesDoesNotBreakOnLastNewline() throws {
        let attachment = DemoTextAttachment(width: 50)
        let string =  NSAttributedString(string: "AB CD\n12 34\nWX YZ\n", attributes: attributes)
        typesetter.typeset(
            string,
            documentRange: NSRange(location: 0, length: 15),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word
            ),
            markedRanges: nil,
            attachments: [.init(range: NSRange(start: 4, end: 15), attachment: attachment)]
        )

        XCTAssertEqual(typesetter.lineFragments.count, 1)
    }
}

/// Covers the height and baseline a line fragment reports, which every line on screen is positioned by.
class TypesetterHeightTests: XCTestCase {
    /// The system font cascades to an emoji face with matched metrics; a named font like Menlo falls back to Apple
    /// Color Emoji, whose metrics are far taller. That's the case that shifts lines.
    let font = NSFont(name: "Menlo", size: 12)!

    /// Typesets one line and returns the height and descent of its only fragment.
    private func fragmentMetrics(
        for string: String,
        baseFont: NSFont?
    ) throws -> (height: CGFloat, descent: CGFloat) {
        // An `NSTextStorage`, like the one a text view lays out, fixes font attributes as it's edited: it rewrites
        // the font over an emoji to Apple Color Emoji, so the attributes can't tell us what font the line is set in.
        let storage = NSTextStorage(string: string)
        storage.addAttribute(.font, value: font, range: NSRange(location: 0, length: storage.length))

        let typesetter = Typesetter()
        typesetter.typeset(
            storage,
            documentRange: NSRange(location: 0, length: storage.length),
            displayData: TextLine.DisplayData(
                maxWidth: .infinity,
                lineHeightMultiplier: 1.0,
                estimatedLineHeight: 20.0,
                breakStrategy: .word,
                baseFont: baseFont
            ),
            markedRanges: nil
        )
        XCTAssertEqual(typesetter.lineFragments.count, 1)
        let fragment = try XCTUnwrap(typesetter.lineFragments.getLine(atIndex: 0)?.data)
        return (fragment.height, fragment.descent)
    }

    /// An emoji has no glyph in a text font, so CoreText draws it with Apple Color Emoji, which declares a much
    /// taller ascent and descent at the same point size. A fragment should keep the height and baseline of the font
    /// the line is set in, so that typing an emoji doesn't shift the line it's on.
    func test_emojiDoesNotChangeFragmentHeight() throws {
        let plain = try fragmentMetrics(for: "hello", baseFont: font)
        let emoji = try fragmentMetrics(for: "hello \u{1F600}", baseFont: font)

        XCTAssertEqual(plain.height, font.ascender - font.descender + font.leading, accuracy: 0.001)
        XCTAssertEqual(emoji.height, plain.height, accuracy: 0.001)
        XCTAssertEqual(emoji.descent, plain.descent, accuracy: 0.001)
    }

    /// Without a font to lay out against, fragments still measure what was drawn.
    func test_withoutBaseFontMetricsComeFromTheDrawnLine() throws {
        let plain = try fragmentMetrics(for: "hello", baseFont: nil)
        let emoji = try fragmentMetrics(for: "hello \u{1F600}", baseFont: nil)

        XCTAssertGreaterThan(emoji.height, plain.height)
    }
}
