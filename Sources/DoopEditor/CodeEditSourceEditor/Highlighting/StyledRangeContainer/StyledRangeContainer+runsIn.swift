//
//  StyledRangeContainer+runsIn.swift
//  CodeEditSourceEditor
//
//  Created by Khan Winter on 7/18/25.
//

import Foundation

extension StyledRangeContainer {
    /// Coalesces all styled runs into a single continuous array of styled runs.
    ///
    /// When there is an overlapping, conflicting style (eg: provider 2 gives `.comment` to the range `0..<2`, and
    /// provider 1 gives `.string` to `1..<2`), the provider with a lower identifier will be prioritized. In the example
    /// case, the final value would be `0..<1=.comment` and `1..<2=.string`.
    ///
    /// - Parameter range: The range to query.
    /// - Returns: An array of continuous styled runs.
    func runsIn(range: NSRange) -> [RangeStoreRun<StyleElement>] {
        func combineLowerPriority(_ lhs: inout RangeStoreRun<StyleElement>, _ rhs: RangeStoreRun<StyleElement>) {
            lhs.value = lhs.value?.combineLowerPriority(rhs.value) ?? rhs.value
        }

        func combineHigherPriority(_ lhs: inout RangeStoreRun<StyleElement>, _ rhs: RangeStoreRun<StyleElement>) {
            lhs.value = lhs.value?.combineHigherPriority(rhs.value) ?? rhs.value
        }

        // Ordered by priority, lower = higher priority.
        let orderedIds = _storage.sorted(by: { $0.value.priority < $1.value.priority }).map(\.key)

        var allRuns: [[RangeStoreRun<StyleElement>]] = []
        allRuns.reserveCapacity(orderedIds.count)
        for id in orderedIds {
            guard var entry = _storage[id] else { continue }
            allRuns.append(entry.store.runs(in: range.intRange))
            // Write the store back so it keeps the query cache it just populated. Applying one provider's
            // highlights re-runs this method, so the stores that didn't change get the identical query again.
            _storage[id] = entry
        }

        /// The shortest run still pending at the end of any provider's array, paired with the index of the
        /// provider it came from.
        ///
        /// That index has to be the provider's index in `allRuns`, because it's used both to address `allRuns`
        /// and — via the `idx < minRunIdx` comparison below — to decide which side of the priority order the
        /// other providers fall on. Enumerating *after* dropping the providers with nothing left would
        /// renumber them, pointing the removal and the priority split at the wrong providers.
        func shortestPendingRun() -> (provider: Int, run: RangeStoreRun<StyleElement>)? {
            allRuns
                .enumerated()
                .compactMap { provider, providerRuns in providerRuns.last.map { (provider: provider, run: $0) } }
                .min(by: { $0.run.length < $1.run.length })
        }

        var runs: [RangeStoreRun<StyleElement>] = []
        var minValue = shortestPendingRun()

        while let value = minValue {
            // Get minimum length off the end of each array
            let minRunIdx = value.provider
            var minRun = value.run

            for idx in (0..<allRuns.count).reversed() where idx != minRunIdx {
                guard let last = allRuns[idx].last else { continue }

                if idx < minRunIdx {
                    combineHigherPriority(&minRun, last)
                } else {
                    combineLowerPriority(&minRun, last)
                }

                if last.length == minRun.length {
                    allRuns[idx].removeLast()
                } else {
                    // safe due to guard a few lines above.
                    allRuns[idx][allRuns[idx].count - 1].subtractLength(minRun)
                }
            }

            // Non-empty by construction: `minRunIdx` is the provider this run was taken from, and the loop
            // above skips it.
            allRuns[minRunIdx].removeLast()

            assert(minRun.length > 0, "Empty or negative runs are not allowed.")
            runs.append(minRun)
            minValue = shortestPendingRun()
        }

        return runs.reversed()
    }
}
