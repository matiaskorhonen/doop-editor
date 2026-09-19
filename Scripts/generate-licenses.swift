#!/usr/bin/env swift
//
// Collect the licences of everything DoopEditor redistributes.
//
// Both of the things this repository ships carry other people's code:
//
//   - the **source package** bundles the `.scm` highlight queries, copied out of the grammar
//     repositories and out of nvim-treesitter by `Scripts/update-queries.sh`;
//   - the **XCFramework** statically links all 40-odd dependencies -- the grammars, TextStory,
//     TextFormation, Rearrange, SwiftTreeSitter, TreeSitter and swift-collections' `_RopeModule`.
//
// Every one of those licences (MIT, BSD 3-Clause, Apache 2.0) requires its text and copyright
// notice to travel with the code, including in binary form. A consumer of the binary package can't
// reach any of them -- the dependencies aren't in its dependency graph at all -- so the notices
// have to be shipped for them.
//
// Two outputs, from one list of dependencies:
//
//   --format markdown   THIRD-PARTY-LICENSES.md, committed at the root of this repository.
//   --format license    The doop-editor-binary LICENSE: this repository's own LICENSE, verbatim
//                       and first so that GitHub and licence scanners still identify the package
//                       as MIT, followed by the same notices as plain text. It goes in `LICENSE`
//                       rather than a file beside it because that is the file licence scanners
//                       read -- mono0926/LicensePlist, which Doop uses, takes the whole contents
//                       of the first `LICENSE`-ish file in a package's checkout as its notice.
//
// Usage: Scripts/generate-licenses.swift [--format markdown|license] [--output PATH] [--check]
//                                        [--checkouts PATH]
//
// --check writes nothing and exits non-zero if the committed file doesn't list exactly the
// dependencies Package.resolved pins, at exactly those versions. It compares the summary table
// rather than regenerating, so it needs no checkouts and no submodule -- a build machine can run
// it as a gate, and it still catches the case it exists for: a dependency added, removed or
// repinned without regenerating.
//
// The dependency set comes from Package.resolved, so it is exactly what the build pins, and the
// licence texts come from the checkouts SwiftPM already made -- run `swift package resolve` first.

import Foundation

// MARK: - Repository layout

let root = URL(fileURLWithPath: #filePath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    .standardizedFileURL
    .deletingLastPathComponent()   // Scripts/
    .deletingLastPathComponent()   // repository root

let usage = """
usage: generate-licenses.swift [--format markdown|license] [--output PATH] [--check]
                               [--checkouts PATH]
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

/// Packages that are resolved for the test target only and are never part of anything shipped.
/// Listing them beats trying to re-derive the link graph here; `swift-custom-dump` is a test
/// dependency in `Package.swift` and `xctest-dynamic-overlay` is its own dependency.
let testOnlyPackages: Set<String> = ["swift-custom-dump", "xctest-dynamic-overlay"]

/// File names to look for in a checkout, in order of preference. Licences travel under several
/// spellings: `LICENSE`, `LICENSE.md` (tree-sitter-lua), `LICENSE.txt` (swift-collections).
let licenseFileNames = ["LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING"]

// MARK: - Arguments

enum Format: String {
    case markdown
    case license
}

var format = Format.markdown
var outputPath: String?
var check = false
var checkoutsPath: String?

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--format":
        guard let value = arguments.next(), let parsed = Format(rawValue: value) else { fail(usage) }
        format = parsed
    case "--output":
        guard let value = arguments.next() else { fail(usage) }
        outputPath = value
    case "--checkouts":
        guard let value = arguments.next() else { fail(usage) }
        checkoutsPath = value
    case "--check":
        check = true
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        fail(usage)
    }
}

// An explicit --output is taken relative to the working directory; the default is the committed
// file at the repository root, wherever the script was run from.
// `--format license` has no default: it builds on this repository's own LICENSE, so writing it
// without being told where would overwrite its own input.
if format == .license, outputPath == nil {
    fail("--format license needs an explicit --output (it must not overwrite this repo's LICENSE)")
}
let output = outputPath.map { URL(fileURLWithPath: $0) }
    ?? root.appendingPathComponent("THIRD-PARTY-LICENSES.md")

/// Where SwiftPM put the checkouts. `swift build`/`swift test` use `.build`; the XCFramework build
/// drives Xcode, which keeps its own copies under `build/DerivedData`. Either will do -- both are
/// checkouts of the revisions `Package.resolved` pins.
func resolveCheckouts() -> URL {
    if let checkoutsPath {
        return URL(fileURLWithPath: checkoutsPath)
    }
    let candidates = [".build/checkouts", "build/DerivedData/SourcePackages/checkouts"]
        .map { root.appendingPathComponent($0) }
    guard let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        fail("no dependency checkouts found -- run `swift package resolve` first")
    }
    return found
}

// MARK: - The dependency set

struct Dependency {
    let name: String        // the repository name, which is also the checkout directory's name
    let url: String         // without the trailing `.git`, so it is a browsable URL
    let pin: String         // "1.2.3" or "revision abc1234"
    let localPath: String?  // set for what isn't a package dependency; relative to the repo root
}

/// Resolved on first use, so `--check` -- which only compares metadata -- doesn't need checkouts.
var cachedCheckouts: URL?

func directory(of dependency: Dependency) -> URL {
    if let localPath = dependency.localPath {
        return root.appendingPathComponent(localPath)
    }
    let checkouts = cachedCheckouts ?? resolveCheckouts()
    cachedCheckouts = checkouts
    return checkouts.appendingPathComponent(dependency.name)
}

struct Notice {
    let dependency: Dependency
    let kind: String        // best-effort SPDX-ish label; the text below it is authoritative
    let license: String
    let notice: String?     // an Apache-2.0 NOTICE file, which has to be redistributed too
}

struct Resolved: Decodable {
    struct Pin: Decodable {
        struct State: Decodable {
            let version: String?
            let revision: String?
        }
        let identity: String
        let location: String
        let state: State
    }
    let pins: [Pin]
}

let resolvedFile = root.appendingPathComponent("Package.resolved")
guard let resolvedData = FileManager.default.contents(atPath: resolvedFile.path),
      let resolved = try? JSONDecoder().decode(Resolved.self, from: resolvedData) else {
    fail("could not read \(resolvedFile.path)")
}

var dependencies: [Dependency] = resolved.pins
    .filter { !testOnlyPackages.contains($0.identity) }
    .map { pin in
        // SwiftPM names a checkout after the last path component of its URL, minus `.git`.
        let name = String(pin.location.split(separator: "/").last ?? "")
            .replacingOccurrences(of: ".git", with: "")
        let pinned: String
        if let version = pin.state.version {
            pinned = version
        } else if let revision = pin.state.revision {
            pinned = "revision \(String(revision.prefix(12)))"
        } else {
            pinned = "unpinned"
        }
        return Dependency(name: name,
                          url: pin.location.replacingOccurrences(of: ".git", with: ""),
                          pin: pinned,
                          localPath: nil)
    }

// nvim-treesitter isn't a package dependency: it's the submodule `Scripts/update-queries.sh` fills
// missing highlight queries from, so its Apache-2.0 code is in the shipped `.scm` resources (each
// copied file carries the notice inline) and its licence has to ship with them.
func submoduleRevision(_ path: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["git", "-C", root.path, "ls-tree", "HEAD", path]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    // "160000 commit <sha>\t<path>"
    return String(decoding: data, as: UTF8.self)
        .split(separator: "\t").first?
        .split(separator: " ").last
        .map { String($0.prefix(12)) }
}

dependencies.append(
    Dependency(name: "nvim-treesitter",
               url: "https://github.com/nvim-treesitter/nvim-treesitter",
               pin: submoduleRevision("Vendor/nvim-treesitter").map { "revision \($0)" } ?? "submodule",
               localPath: "Vendor/nvim-treesitter")
)

dependencies.sort { $0.name.lowercased() < $1.name.lowercased() }

// MARK: - Checking the committed file

// `--check` compares the summary table's `| [name](url) | pin | kind |` rows against the
// dependencies above. Nothing is read from disk beyond Package.resolved and git's own index,
// so it runs anywhere.
if check {
    guard let existing = try? String(contentsOf: output, encoding: .utf8) else {
        fail("""
        \(output.lastPathComponent) is missing
        run: Scripts/generate-licenses.swift
        """)
    }
    let listed = existing.split(separator: "\n")
        .filter { $0.hasPrefix("| [") }
        .map { row -> String in
            let cells = row.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            let name = cells.first?.drop(while: { $0 != "[" }).dropFirst().prefix(while: { $0 != "]" }) ?? ""
            return "\(name) \(cells.count > 1 ? cells[1] : "")"
        }
    let expected = dependencies.map { "\($0.name) \($0.pin)" }
    guard listed == expected else {
        let added = Set(expected).subtracting(listed).sorted()
        let removed = Set(listed).subtracting(expected).sorted()
        fail("""
        \(output.lastPathComponent) is out of date with Package.resolved
        \(added.isEmpty ? "" : "\n  missing:  \(added.joined(separator: ", "))")\
        \(removed.isEmpty ? "" : "\n  stale:    \(removed.joined(separator: ", "))")
        run: Scripts/generate-licenses.swift
        """)
    }
    print("\(output.lastPathComponent) lists all \(expected.count) pinned dependencies")
    exit(0)
}

// MARK: - Reading the licences

/// A rough SPDX label, for the summary table. The full text always follows, so a wrong guess is
/// cosmetic -- but an unrecognised licence is worth a person's attention, so it says so loudly.
func licenseKind(_ text: String) -> String {
    if text.contains("Apache License") { return "Apache-2.0" }
    if text.contains("BSD 3-Clause") || text.contains("Neither the name") { return "BSD-3-Clause" }
    if text.contains("Permission is hereby granted, free of charge") { return "MIT" }
    return "see text"
}

func firstFile(named names: [String], in directory: URL) -> URL? {
    names.lazy
        .map { directory.appendingPathComponent($0) }
        .first { FileManager.default.fileExists(atPath: $0.path) }
}

func read(_ url: URL) -> String {
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        fail("could not read \(url.path)")
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

let notices: [Notice] = dependencies.map { dependency in
    let source = directory(of: dependency)
    guard FileManager.default.fileExists(atPath: source.path) else {
        fail("""
        no checkout of \(dependency.name) at \(source.path)
        \(dependency.localPath == nil
            ? "run `swift package resolve`"
            : "run `git submodule update --init \(dependency.localPath!)`")
        """)
    }
    guard let licenseFile = firstFile(named: licenseFileNames, in: source) else {
        // Not a nit: shipping code whose licence we can't find is the thing this script exists
        // to prevent, so stop rather than quietly leaving it out.
        fail("no licence file in \(source.path) -- add its spelling to licenseFileNames")
    }
    let license = read(licenseFile)
    // Apache-2.0 section 4(d): a NOTICE file has to be redistributed with derivative works.
    let notice = firstFile(named: ["NOTICE", "NOTICE.md", "NOTICE.txt"], in: source).map(read)
    return Notice(dependency: dependency, kind: licenseKind(license), license: license, notice: notice)
}

// MARK: - Rendering

let preamble = """
DoopEditor is distributed both as source and as a prebuilt XCFramework. The source package bundles
tree-sitter highlight queries copied from the grammar repositories and from nvim-treesitter, and
the XCFramework additionally links every dependency statically, so in both forms this software
redistributes the work below. Each item's licence and copyright notice is reproduced in full, as
those licences require.

The versions are the ones pinned in Package.resolved for this release.
"""

let generatedBy = """
Generated by Scripts/generate-licenses.swift in matiaskorhonen/doop-editor -- do not edit by hand.
"""

func markdownDocument() -> String {
    var lines = ["# Third-party licenses", "", preamble, "", generatedBy, "", "| Package | Version | License |", "| --- | --- | --- |"]
    for notice in notices {
        lines.append("| [\(notice.dependency.name)](\(notice.dependency.url)) | \(notice.dependency.pin) | \(notice.kind) |")
    }
    for notice in notices {
        lines.append(contentsOf: ["", "## \(notice.dependency.name)", ""])
        lines.append("\(notice.dependency.url) — \(notice.dependency.pin) — \(notice.kind)")
        lines.append(contentsOf: ["", "```", notice.license, "```"])
        if let text = notice.notice {
            lines.append(contentsOf: ["", "NOTICE:", "", "```", text, "```"])
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

func licenseDocument() -> String {
    let own = read(root.appendingPathComponent("LICENSE"))
    let rule = String(repeating: "-", count: 78)
    var lines = [own, "", rule, "", "THIRD-PARTY LICENSES", "", preamble, "", generatedBy]
    for notice in notices {
        lines.append(contentsOf: ["", rule, "", notice.dependency.name,
                                  "\(notice.dependency.url)",
                                  "\(notice.dependency.pin) — \(notice.kind)", "", notice.license])
        if let text = notice.notice {
            lines.append(contentsOf: ["", "NOTICE:", "", text])
        }
    }
    return lines.joined(separator: "\n") + "\n"
}

let document = format == .markdown ? markdownDocument() : licenseDocument()

// MARK: - Write

do {
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    try document.write(to: output, atomically: true, encoding: .utf8)
} catch {
    fail("could not write \(output.path): \(error)")
}
print("wrote \(output.path) (\(notices.count) dependencies)")
