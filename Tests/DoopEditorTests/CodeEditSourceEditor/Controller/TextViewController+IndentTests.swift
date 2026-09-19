//
//  TextViewController+IndentTests.swift
//  CodeEditSourceEditor
//
//  Created by Ludwig, Tom on 08.10.24.
//

import XCTest
@testable import CodeEditSourceEditor
@testable import CodeEditTextView
import CustomDump

final class TextViewControllerIndentTests: XCTestCase {
    var controller: TextViewController!

    override func setUpWithError() throws {
        controller = Mock.textViewController(theme: Mock.theme())

        controller.loadView()
    }

    func testHandleIndentWithSpacesInwards() {
        controller.setText("    This is a test string")
        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 0))]
        controller.cursorPositions = cursorPositions
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 0))]
        controller.handleIndent(inwards: true)

        expectNoDifference(controller.text, "This is a test string")

        // Normally, 4 spaces are used for indentation; however, now we only insert 2 leading spaces.
        // The outcome should be the same, though.
        controller.setText("  This is a test string")
        controller.cursorPositions = cursorPositions
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 0))]
        controller.handleIndent(inwards: true)

        expectNoDifference(controller.text, "This is a test string")
    }

    func testHandleIndentWithSpacesOutwards() {
        controller.setText("This is a test string")
        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 0))]
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 0))]
        controller.cursorPositions = cursorPositions

        controller.handleIndent(inwards: false)

        expectNoDifference(controller.text, "    This is a test string")
    }

    func testHandleIndentWithTabsInwards() {
        controller.setText("\tThis is a test string")
        controller.configuration.behavior .indentOption = .tab
        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 0))]
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 0))]
        controller.cursorPositions = cursorPositions

        controller.handleIndent(inwards: true)

        expectNoDifference(controller.text, "This is a test string")
    }

    func testHandleIndentWithTabsOutwards() {
        controller.setText("This is a test string")
        controller.configuration.behavior.indentOption = .tab
        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 0))]
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 0))]
        controller.cursorPositions = cursorPositions

        controller.handleIndent()

        // Normally, we expect nothing to happen because only one line is selected.
        // However, this logic is not handled inside `handleIndent`.
        expectNoDifference(controller.text, "\tThis is a test string")
    }

    func testHandleIndentMultiLine() {
        controller.configuration.behavior.indentOption = .tab
        let strings: [(NSString, Int)] = [
            ("This is a test string\n", 0),
            ("With multiple lines\n", 22),
            ("And some indentation", 42),
        ]
        for (insertedString, location) in strings {
            controller.textView.replaceCharacters(
                in: [NSRange(location: location, length: 0)],
                with: insertedString as String
            )
        }

        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 62))]
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 62))]
        controller.cursorPositions = cursorPositions

        controller.handleIndent()
        let expectedString = "\tThis is a test string\n\tWith multiple lines\n\tAnd some indentation"
        expectNoDifference(controller.text, expectedString)
    }

    func testHandleInwardIndentMultiLine() {
        controller.configuration.behavior.indentOption = .tab
        let strings: [(NSString, NSRange)] = [
            ("\tThis is a test string\n", NSRange(location: 0, length: 0)),
            ("\tWith multiple lines\n", NSRange(location: 23, length: 0)),
            ("\tAnd some indentation", NSRange(location: 44, length: 0)),
        ]
        for (insertedString, location) in strings {
            controller.textView.replaceCharacters(
                in: [location],
                with: insertedString as String
            )
        }

        let cursorPositions = [CursorPosition(range: NSRange(location: 0, length: controller.text.count))]
        controller.textView.selectionManager.textSelections = [.init(range: NSRange(location: 0, length: 62))]
        controller.cursorPositions = cursorPositions

        controller.handleIndent(inwards: true)
        let expectedString = "This is a test string\nWith multiple lines\nAnd some indentation"
        expectNoDifference(controller.text, expectedString)
    }

    /// Reproduces a bug where de-indenting a selection that starts at the very beginning of a line
    /// (i.e. the selection includes the leading whitespace being removed) causes the selection to drift
    /// upwards by one indent-width, "eating" part of the previous line. Selecting whole lines and pressing
    /// shift-tab should keep the same lines selected — only their content should change.
    func testHandleIndentInwardsKeepsSelectionAtLineStartAfterOnePress() {
        controller.configuration.behavior.indentOption = .spaces(count: 2)
        controller.setText("{\n  \"a\": {\n    \"b\": 1,\n    \"c\": 2\n  }\n}")

        // Select from the start of line 1 (`  "a": {`) through the end of `}` on line 4 (`  }`),
        // mirroring "select these whole lines, then shift-tab".
        let selectionRange = NSRange(location: 2, length: 35)
        controller.textView.selectionManager.textSelections = [.init(range: selectionRange)]
        controller.cursorPositions = [CursorPosition(range: selectionRange)]

        controller.handleIndent(inwards: true)

        expectNoDifference(controller.text, "{\n\"a\": {\n  \"b\": 1,\n  \"c\": 2\n}\n}")

        // The selection should still start exactly where line 1 now begins (nothing before that point
        // was touched), and should still span the same four lines. Before the fix, the location is
        // shifted two characters too far to the left, spilling into the previous line.
        let newRange = controller.textView.selectionManager.textSelections[0].range
        expectNoDifference(newRange, NSRange(location: 2, length: 27))
    }

    /// The same drift compounds with repeated presses: each additional de-indent shifts the selection
    /// further out of alignment with the lines it started on.
    func testHandleIndentInwardsRepeatedPressesKeepSelectionStable() {
        controller.configuration.behavior.indentOption = .spaces(count: 2)
        controller.setText("{\n  \"a\": {\n    \"b\": 1,\n    \"c\": 2\n  }\n}")

        let selectionRange = NSRange(location: 2, length: 35)
        controller.textView.selectionManager.textSelections = [.init(range: selectionRange)]
        controller.cursorPositions = [CursorPosition(range: selectionRange)]

        controller.handleIndent(inwards: true)
        controller.handleIndent(inwards: true)

        // Two presses can only remove up to 2 spaces per line (4 max on lines "b"/"c"), so the text
        // should bottom out fully de-indented — it should never lose the closing braces or otherwise
        // mangle content just because the selection drifted.
        expectNoDifference(controller.text, "{\n\"a\": {\n\"b\": 1,\n\"c\": 2\n}\n}")

        let newRange = controller.textView.selectionManager.textSelections[0].range
        expectNoDifference(newRange, NSRange(location: 2, length: 23))
    }

    func testMultipleLinesHighlighted() {
        controller.setText("\tThis is a test string\n\tWith multiple lines\n\tAnd some indentation")
        var cursorPositions = [CursorPosition(range: NSRange(location: 0, length: controller.text.count))]
        controller.cursorPositions = cursorPositions

        XCTAssert(controller.multipleLinesHighlighted())

        cursorPositions = [CursorPosition(range: NSRange(location: 0, length: 5))]
        controller.cursorPositions = cursorPositions

        XCTAssertFalse(controller.multipleLinesHighlighted())
    }
}
