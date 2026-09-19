#!/usr/bin/env swift
//
// Generate the doop-editor-binary package from a completed xcframework build.
//
// The XCFrameworks are attached to the doop-editor GitHub release for a version; the package that
// points at them lives in its own repository, doop-editor-binary, tagged with the same version.
// Keeping it out of this repo means each repository has exactly one tag per version -- SwiftPM
// strips a leading `v` when reading tags, so a `v0.9.0` and a `0.9.0` in one repo are two tags for
// the same version, and it silently resolves whichever it prefers.
//
// `.binaryTarget` can't declare dependencies, so each product lists every binary target it needs
// transitively -- that's what makes SwiftPM link and embed the whole set when a consumer depends on
// the product.
//
// Usage: Scripts/generate-binary-manifest.swift <vX.Y.Z> [--source-repo owner/name]
//                                                        [--binary-repo owner/name]
// Reads build/xcframeworks/binary-targets.txt (module, checksum and direct dependencies, written by
// Scripts/build-xcframeworks.sh) and writes build/binary-package/{Package.swift,README.md}.

import Foundation

let root = URL(fileURLWithPath: #filePath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    .standardizedFileURL
    .deletingLastPathComponent()   // Scripts/
    .deletingLastPathComponent()   // repository root
let targetsFile = root.appendingPathComponent("build/xcframeworks/binary-targets.txt")
let outputDirectory = root.appendingPathComponent("build/binary-package")

let usage = "usage: generate-binary-manifest.swift <vX.Y.Z> [--source-repo owner/name] [--binary-repo owner/name]"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

// The single product's roots. The target list is the transitive closure of these over the link
// graph recorded by Scripts/build-xcframeworks.sh. With everything absorbed into one framework
// that closure is just DoopEditor itself, but it stays computed rather than assumed: if a
// dependency ever stops being absorbed, this picks it up instead of shipping a broken manifest.
let productRoots: [(product: String, roots: [String])] = [
    ("DoopEditor", ["DoopEditor"]),
]

// MARK: - Arguments

var version: String?
var sourceRepo = "matiaskorhonen/doop-editor"
var binaryRepo = "matiaskorhonen/doop-editor-binary"

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "--source-repo":
        guard let value = arguments.next() else { fail(usage) }
        sourceRepo = value
    case "--binary-repo":
        guard let value = arguments.next() else { fail(usage) }
        binaryRepo = value
    case "-h", "--help":
        print(usage)
        exit(0)
    default:
        guard version == nil, !argument.hasPrefix("-") else { fail(usage) }
        version = argument
    }
}

guard let version else { fail(usage) }

// Matches the tags this repo already uses. The release assets live under the tag name, so a
// version without the `v` would produce download URLs that 404.
guard version.range(of: #"^v\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$"#, options: .regularExpression) != nil else {
    fail("version must be a tag like v0.9.0, got '\(version)'")
}

// MARK: - Build results

guard let targetsContents = try? String(contentsOf: targetsFile, encoding: .utf8) else {
    fail("missing \(targetsFile.path) -- run Scripts/build-xcframeworks.sh first")
}

var order: [String] = []
var checksums: [String: String] = [:]
var dependencies: [String: [String]] = [:]

for line in targetsContents.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
    let fields = line.split(separator: " ").map(String.init)
    guard fields.count == 3 else { fail("malformed line in \(targetsFile.path): \(line)") }
    let (module, checksum, deps) = (fields[0], fields[1], fields[2])
    order.append(module)
    checksums[module] = checksum
    dependencies[module] = deps == "-" ? [] : deps.split(separator: ",").map(String.init)
}

/// Every framework reachable from `roots`, in a stable breadth-first order.
func closure(_ roots: [String]) -> [String] {
    var ordered: [String] = []
    var queue = roots
    while !queue.isEmpty {
        let name = queue.removeFirst()
        guard !ordered.contains(name) else { continue }
        ordered.append(name)
        queue.append(contentsOf: dependencies[name] ?? [])
    }
    return ordered
}

let products = productRoots.map { (product: $0.product, targets: closure($0.roots)) }

let missing = Set(products.flatMap(\.targets)).subtracting(checksums.keys)
guard missing.isEmpty else {
    fail("no checksum for: \(missing.sorted().joined(separator: ", "))")
}

// MARK: - Package.swift

let downloadBase = "https://github.com/\(sourceRepo)/releases/download/\(version)"

var manifest: [String] = [
    "// swift-tools-version: 5.9",
    "//",
    "// Prebuilt DoopEditor \(version).",
    "//",
    "// Generated by Scripts/generate-binary-manifest.swift in \(sourceRepo) -- do not edit by hand.",
    "// The XCFramework is attached to the matching release there.",
    "//",
    "// `.binaryTarget` cannot declare dependencies, so the product lists every framework it",
    "// needs transitively -- which is normally just itself, unless a dependency stopped being absorbed.",
    "import PackageDescription",
    "",
    "let package = Package(",
    "    name: \"DoopEditor\",",
    "    platforms: [.macOS(.v13)],",
    "    products: [",
]
for product in products {
    manifest.append("        .library(")
    manifest.append("            name: \"\(product.product)\",")
    manifest.append("            targets: [")
    for target in product.targets {
        manifest.append("                \"\(target)\",")
    }
    manifest.append("            ]")
    manifest.append("        ),")
}
manifest.append("    ],")
manifest.append("    targets: [")
for module in order {
    manifest.append("        .binaryTarget(")
    manifest.append("            name: \"\(module)\",")
    manifest.append("            url: \"\(downloadBase)/\(module).xcframework.zip\",")
    manifest.append("            checksum: \"\(checksums[module]!)\"")
    manifest.append("        ),")
}
manifest.append("    ]")
manifest.append(")")

// MARK: - README.md

let identity = binaryRepo.split(separator: "/").last.map(String.init) ?? binaryRepo
let sourceIdentity = sourceRepo.split(separator: "/").last.map(String.init) ?? sourceRepo
let semver = String(version.dropFirst())   // the `v` is guaranteed by the check above
let productNames = Set(productRoots.map(\.product))
let supporting = order.filter { !productNames.contains($0) }.map { "- `\($0)`" }.joined(separator: "\n")
// Normally empty: everything is absorbed into the one framework. A dependency that stopped being
// absorbed would ship alongside it and needs saying out loud.
let supportingSection = supporting.isEmpty ? "" : """
\nThese frameworks ship alongside it, because the module's public interface names them or it loads
them at runtime:\n\n\(supporting)\n
"""

let readme = """
# DoopEditor (prebuilt)

Prebuilt macOS XCFramework of [\(sourceRepo)](https://github.com/\(sourceRepo)). Depending
on this package instead of the source one skips cloning and compiling the 40+ tree-sitter
grammar packages, which are statically linked into the framework.

This repository holds only the generated `Package.swift`. The framework itself is
attached to the [\(version) release](https://github.com/\(sourceRepo)/releases/tag/\(version))
of the source repository, and each tag here matches a tag there.

```swift
dependencies: [
    .package(url: "https://github.com/\(binaryRepo).git", from: "\(semver)"),
],
```

The product is the same as the source package's -- `DoopEditor` -- but SwiftPM names a package
after its repository, so switching from source to binary changes the `package:` in the product
reference:

```swift
.product(name: "DoopEditor", package: "\(identity)"),  // was "\(sourceIdentity)"
```

\(supportingSection)
Generated for \(version) by `Scripts/generate-binary-manifest.swift` in the source repository --
do not edit by hand; changes here are overwritten by the next release.

"""

// MARK: - Write

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    for (name, contents) in [("Package.swift", manifest.joined(separator: "\n") + "\n"), ("README.md", readme)] {
        try contents.write(to: outputDirectory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        print("wrote build/binary-package/\(name)")
    }
} catch {
    fail("could not write the binary package: \(error)")
}
