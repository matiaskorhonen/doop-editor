import XCTest
@testable import CodeEditSourceEditor

final class StyledRangeContainerTests: XCTestCase {
    typealias Run = RangeStoreRun<StyledRangeContainer.StyleElement>

    @MainActor
    func test_init() {
        let providers = [0, 1]
        let store = StyledRangeContainer(documentLength: 100, providers: providers)

        // Have to do string conversion due to missing Comparable conformance pre-macOS 14
        XCTAssertEqual(store._storage.keys.sorted(), providers)
        XCTAssert(
            store._storage.values.allSatisfy({ $0.store.length == 100 }),
            "One or more providers have incorrect length"
        )
    }

    @MainActor
    func test_setHighlights() {
        let providers = [0, 1]
        let store = StyledRangeContainer(documentLength: 100, providers: providers)

        store.applyHighlightResult(
            provider: providers[0],
            highlights: [HighlightRange(range: NSRange(location: 40, length: 10), capture: .comment)],
            rangeToHighlight: NSRange(location: 0, length: 100)
        )

        XCTAssertNotNil(store._storage[providers[0]])
        XCTAssertEqual(store._storage[providers[0]]!.store.count, 3)
        XCTAssertNil(store._storage[providers[0]]!.store.runs(in: 0..<100)[0].value?.capture)
        XCTAssertEqual(store._storage[providers[0]]!.store.runs(in: 0..<100)[1].value?.capture, .comment)
        XCTAssertNil(store._storage[providers[0]]!.store.runs(in: 0..<100)[2].value?.capture)

        XCTAssertEqual(
            store.runsIn(range: NSRange(location: 0, length: 100)),
            [
                Run(length: 40, value: nil),
                Run(length: 10, value: .init(capture: .comment, modifiers: [])),
                Run(length: 50, value: nil)
            ]
        )
    }

    @MainActor
    func test_overlappingRuns() {
        let providers = [0, 1]
        let store = StyledRangeContainer(documentLength: 100, providers: providers)

        store.applyHighlightResult(
            provider: providers[0],
            highlights: [HighlightRange(range: NSRange(location: 40, length: 10), capture: .comment)],
            rangeToHighlight: NSRange(location: 0, length: 100)
        )

        store.applyHighlightResult(
            provider: providers[1],
            highlights: [
                HighlightRange(range: NSRange(location: 45, length: 5), capture: nil, modifiers: [.declaration])
            ],
            rangeToHighlight: NSRange(location: 0, length: 100)
        )

        XCTAssertEqual(
            store.runsIn(range: NSRange(location: 0, length: 100)),
            [
                Run(length: 40, value: nil),
                Run(length: 5, value: .init(capture: .comment, modifiers: [])),
                Run(length: 5, value: .init(capture: .comment, modifiers: [.declaration])),
                Run(length: 50, value: nil)
            ]
        )
    }

    @MainActor
    func test_overlappingRunsWithMoreProviders() {
        let providers = [0, 1, 2]
        let store = StyledRangeContainer(documentLength: 200, providers: providers)

        store.applyHighlightResult(
            provider: providers[0],
            highlights: [
                HighlightRange(range: NSRange(location: 30, length: 20), capture: .comment),
                HighlightRange(range: NSRange(location: 80, length: 30), capture: .string)
            ],
            rangeToHighlight: NSRange(location: 0, length: 200)
        )

        store.applyHighlightResult(
            provider: providers[1],
            highlights: [
                HighlightRange(range: NSRange(location: 35, length: 10), capture: nil, modifiers: [.declaration]),
                HighlightRange(range: NSRange(location: 90, length: 15), capture: .comment, modifiers: [.static])
            ],
            rangeToHighlight: NSRange(location: 0, length: 200)
        )

        store.applyHighlightResult(
            provider: providers[2],
            highlights: [
                HighlightRange(range: NSRange(location: 40, length: 5), capture: .function, modifiers: [.abstract]),
                HighlightRange(range: NSRange(location: 100, length: 10), capture: .number, modifiers: [.modification])
            ],
            rangeToHighlight: NSRange(location: 0, length: 200)
        )

        let runs = store.runsIn(range: NSRange(location: 0, length: 200))

        XCTAssertEqual(runs.reduce(0, { $0 + $1.length}), 200)

        XCTAssertEqual(runs[0], Run(length: 30, value: nil))
        XCTAssertEqual(runs[1], Run(length: 5, value: .init(capture: .comment, modifiers: [])))
        XCTAssertEqual(runs[2], Run(length: 5, value: .init(capture: .comment, modifiers: [.declaration])))
        XCTAssertEqual(runs[3], Run(length: 5, value: .init(capture: .comment, modifiers: [.abstract, .declaration])))
        XCTAssertEqual(runs[4], Run(length: 5, value: .init(capture: .comment, modifiers: [])))
        XCTAssertEqual(runs[5], Run(length: 30, value: nil))
        XCTAssertEqual(runs[6], Run(length: 10, value: .init(capture: .string, modifiers: [])))
        XCTAssertEqual(runs[7], Run(length: 10, value: .init(capture: .string, modifiers: [.static])))
        XCTAssertEqual(runs[8], Run(length: 5, value: .init(capture: .string, modifiers: [.static, .modification])))
        XCTAssertEqual(runs[9], Run(length: 5, value: .init(capture: .string, modifiers: [.modification])))
        XCTAssertEqual(runs[10], Run(length: 90, value: nil))
    }

    /// Conflicting captures are resolved by each provider's *priority*, which `runsIn` tracks by the provider's
    /// position in the priority-sorted list. Flipping the priorities has to flip the winner, so the ordering is
    /// genuinely keyed on priority rather than on dictionary or insertion order.
    @MainActor
    func test_priorityDecidesConflictingCaptures() {
        let providers = [0, 1]
        let store = StyledRangeContainer(documentLength: 100, providers: providers)

        for (provider, capture) in zip(providers, [CaptureName.comment, .string]) {
            store.applyHighlightResult(
                provider: provider,
                highlights: [HighlightRange(range: NSRange(location: 0, length: 100), capture: capture)],
                rangeToHighlight: NSRange(location: 0, length: 100)
            )
        }

        // Providers default to a priority equal to their id, and lower wins.
        XCTAssertEqual(
            store.runsIn(range: NSRange(location: 0, length: 100)),
            [Run(length: 100, value: .init(capture: .comment, modifiers: []))]
        )

        store.setPriority(providerId: providers[1], priority: -1)

        XCTAssertEqual(
            store.runsIn(range: NSRange(location: 0, length: 100)),
            [Run(length: 100, value: .init(capture: .string, modifiers: []))],
            "Expected the reprioritized provider's capture to win"
        )
    }

    /// Providers contribute different numbers of runs over the same range, so the coalescing loop walks their
    /// arrays at different rates. It addresses providers by index throughout — including to split them into
    /// higher- and lower-priority halves — so those indices must keep pointing at the provider they started on.
    @MainActor
    func test_providersWithDifferingRunCountsStayAligned() {
        let providers = [0, 1]
        let store = StyledRangeContainer(documentLength: 60, providers: providers)

        // One run for the low-priority provider...
        store.applyHighlightResult(
            provider: providers[1],
            highlights: [HighlightRange(range: NSRange(location: 0, length: 60), capture: .string)],
            rangeToHighlight: NSRange(location: 0, length: 60)
        )

        // ...against six for the high-priority one.
        store.applyHighlightResult(
            provider: providers[0],
            highlights: (0..<3).map {
                HighlightRange(range: NSRange(location: $0 * 20, length: 10), capture: .comment)
            },
            rangeToHighlight: NSRange(location: 0, length: 60)
        )

        let runs = store.runsIn(range: NSRange(location: 0, length: 60))

        XCTAssertEqual(runs.reduce(0, { $0 + $1.length }), 60)
        XCTAssertEqual(
            runs,
            [
                Run(length: 10, value: .init(capture: .comment, modifiers: [])),
                Run(length: 10, value: .init(capture: .string, modifiers: [])),
                Run(length: 10, value: .init(capture: .comment, modifiers: [])),
                Run(length: 10, value: .init(capture: .string, modifiers: [])),
                Run(length: 10, value: .init(capture: .comment, modifiers: [])),
                Run(length: 10, value: .init(capture: .string, modifiers: []))
            ]
        )
    }
}
