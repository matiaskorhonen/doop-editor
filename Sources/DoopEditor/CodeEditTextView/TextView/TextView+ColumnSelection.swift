//
//  TextView+ColumnSelection.swift
//  CodeEditTextView
//
//  Created by Khan Winter on 6/19/25.
//

import AppKit

extension TextView {
    /// Set the user's selection to a square region in the editor.
    ///
    /// This method will automatically determine a valid region from the provided two points. Every line the region
    /// covers gets a selection, so lines too short to reach the region - blank ones included - get a cursor at
    /// their end rather than being dropped.
    /// - Parameters:
    ///   - pointA: The first point.
    ///   - pointB: The second point.
    public func selectColumns(betweenPointA pointA: CGPoint, pointB: CGPoint) {
        let start = CGPoint(x: min(pointA.x, pointB.x), y: min(pointA.y, pointB.y))
        let end = CGPoint(x: max(pointA.x, pointB.x), y: max(pointA.y, pointB.y))

        // Collect all overlapping text ranges. The iterator's maximum y is exclusive, and both points come from
        // somewhere the user pointed at, so nudge it past `end.y` to include the line that contains it - a point
        // exactly on a line's top edge belongs to that line everywhere else in the layout manager.
        let selectedRanges: [NSRange] = layoutManager
            .linesStartingAt(start.y, until: end.y.nextUp)
            .flatMap { textLine in
                // Collect fragment ranges
                textLine.data.lineFragments.compactMap { lineFragment -> NSRange? in
                    let startOffset = self.layoutManager.textOffsetAtPoint(
                        start,
                        fragmentPosition: lineFragment,
                        linePosition: textLine
                    )
                    let endOffset = self.layoutManager.textOffsetAtPoint(
                        end,
                        fragmentPosition: lineFragment,
                        linePosition: textLine
                    )
                    guard let startOffset, let endOffset else { return nil }

                    return NSRange(start: startOffset, end: endOffset)
                }
            }

        selectionManager.setSelectedRanges(selectedRanges)
    }
}
