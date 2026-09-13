#!/usr/bin/env swift
//
// Generate the XcodeGen spec used to build DoopEditor's distributable XCFrameworks.
//
// The spec is derived from the package itself so it cannot drift from the source build: the
// grammar products come from SwiftPM's parsed manifest (`swift package dump-package`), and
// every package is pinned to the exact revision in Package.resolved.
//
// Run via Scripts/build-xcframeworks.sh, which resolves the package first: the third-party
// framework targets build straight out of .build/checkouts.
//
// Usage: Scripts/generate-binary-project.swift

import Foundation

let root = URL(fileURLWithPath: #filePath, relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    .standardizedFileURL
    .deletingLastPathComponent()   // Scripts/
    .deletingLastPathComponent()   // repository root
let outputDirectory = root.appendingPathComponent("BinaryDistribution")
let output = outputDirectory.appendingPathComponent("project.yml")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - Package inputs

/// (product, package identity) for each tree-sitter grammar the CodeEditLanguages target links.
func grammarProducts() -> [(product: String, package: String)] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "package", "--package-path", root.path, "dump-package"]
    let pipe = Pipe()
    process.standardOutput = pipe
    do { try process.run() } catch { fail("could not run `swift package dump-package`: \(error)") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { fail("`swift package dump-package` failed") }

    struct Manifest: Decodable {
        struct Target: Decodable {
            let name: String
            let dependencies: [Dependency]
        }
        /// Only product dependencies matter here: `{"product": [name, package, moduleAliases, condition]}`.
        struct Dependency: Decodable {
            let product: [String?]?
        }
        let targets: [Target]
    }

    guard let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
          let languages = manifest.targets.first(where: { $0.name == "CodeEditLanguages" })
    else { fail("could not read the CodeEditLanguages target from the manifest") }

    return languages.dependencies.compactMap { dependency in
        guard let product = dependency.product, product.count >= 2,
              let name = product[0], let package = product[1],
              package != "swift-tree-sitter"
        else { return nil }
        return (name, package)
    }
}

/// identity -> (location, revision), so the binary is built from what the source build resolved.
func resolvedRevisions() -> [String: (location: String, revision: String)] {
    struct Resolved: Decodable {
        struct Pin: Decodable {
            struct State: Decodable { let revision: String }
            let identity: String
            let location: String
            let state: State
        }
        let pins: [Pin]
    }
    let file = root.appendingPathComponent("Package.resolved")
    guard let data = try? Data(contentsOf: file),
          let resolved = try? JSONDecoder().decode(Resolved.self, from: data)
    else { fail("could not read \(file.path) -- run `swift package resolve` first") }
    return Dictionary(uniqueKeysWithValues: resolved.pins.map { ($0.identity, ($0.location, $0.state.revision)) })
}

/// The tree-sitter query directories, copied as folder references to preserve their structure.
func languageResources() -> [String] {
    let base = root.appendingPathComponent("CodeEditLanguages/Sources/CodeEditLanguages/Resources")
    let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
    return names.filter { name in
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: base.appendingPathComponent(name).path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }.sorted()
}

// MARK: - Paths

// The spec lives in BinaryDistribution/, one level below the root.

func checkout(_ path: String) -> String {
    let absolute = root.appendingPathComponent(".build/checkouts/\(path)")
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: absolute.path, isDirectory: &isDirectory), isDirectory.boolValue else {
        fail("missing checkout: \(absolute.path)\nRun `swift package resolve` first.")
    }
    return "../.build/checkouts/\(path)"
}

func local(_ path: String) -> String {
    "../\(path)"
}

// MARK: - Spec

var lines: [String] = []
func add(_ line: String = "") { lines.append(line) }

/// Per-target settings.
///
/// SKIP_INSTALL has to be set per target: XcodeGen writes `SKIP_INSTALL = YES` at the target
/// level for framework targets, which overrides the project-level value, and an archive with
/// SKIP_INSTALL on contains no framework to turn into an XCFramework.
///
/// These belong here rather than on the xcodebuild command line, because command-line settings
/// also apply to the SwiftPM dependencies -- and swift-collections does not compile with
/// library evolution enabled.
func settings(_ extra: [(String, String)] = []) {
    add("    settings:")
    add("      base:")
    add("        SKIP_INSTALL: NO")
    for (key, value) in extra {
        add("        \(key): \(value)")
    }
}

let grammars = grammarProducts()
let revisions = resolvedRevisions()
let resources = languageResources()

func pin(_ identity: String) -> (location: String, revision: String) {
    guard let pin = revisions[identity] else { fail("\(identity) is not pinned in Package.resolved") }
    return pin
}

add("# Generated by Scripts/generate-binary-project.swift -- do not edit by hand.")
add("name: DoopEditorBinary")
add("options:")
add("  deploymentTarget: { macOS: \"13.0\" }")
add("  createIntermediateGroups: true")
add("  defaultConfig: Release")
add()
add("configs:")
add("  Release: release")
add()
add("settings:")
add("  base:")
// BUILD_LIBRARY_FOR_DISTRIBUTION is what emits the .swiftinterface that makes the binaries usable
// from a different compiler than the one that built them.
add("    BUILD_LIBRARY_FOR_DISTRIBUTION: YES")
add("    SKIP_INSTALL: NO")
add("    DYLIB_INSTALL_NAME_BASE: \"@rpath\"")
add("    MACOSX_DEPLOYMENT_TARGET: \"13.0\"")
add("    ARCHS: \"arm64 x86_64\"")
add("    ONLY_ACTIVE_ARCH: NO")
add("    SWIFT_VERSION: \"5.10\"")
add("    DEFINES_MODULE: YES")
add("    CODE_SIGN_IDENTITY: \"\"")
add("    CODE_SIGNING_REQUIRED: NO")
add("    CODE_SIGNING_ALLOWED: NO")
add("    SWIFT_INSTALL_OBJC_HEADER: NO")
add()

add("packages:")
for package in Set(grammars.map(\.package)).sorted() + ["swift-collections"] {
    let (location, revision) = pin(package)
    add("  \(package):")
    add("    url: \(location)")
    add("    revision: \(revision)")
}
add()

add("targets:")

// --- dependency layer ---------------------------------------------------------------------------
// TextStory re-exports TSYTextStorage from its `Internal` ObjC target through a public typealias,
// so `Internal` lands in TextStory's interface and has to ship under that name.
add("  Internal:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("TextStory/Sources/Internal"))")
add("        headerVisibility: public")
add("      - path: Support/Internal.h")
add("        headerVisibility: public")
settings()
add()

add("  Rearrange:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("Rearrange/Sources/Rearrange"))")
add("        excludes: [\"Documentation.docc\"]")
settings()
add()

add("  TextStory:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("TextStory/Sources/TextStory"))")
add("        excludes: [\"Documentation.docc\"]")
add("    dependencies:")
add("      - target: Internal")
add("      - target: Rearrange")
settings()
add()

add("  TextFormation:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("TextFormation/Sources/TextFormation"))")
add("        excludes: [\"Documentation.docc\"]")
add("    dependencies:")
add("      - target: TextStory")
add("      - target: Rearrange")
settings()
add()

// Mirrors the tree-sitter package's own C target settings (path lib, sources src, public headers
// include, and the POSIX feature defines it needs).
add("  TreeSitter:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("tree-sitter/lib/src"))")
add("        excludes: [\"lib.c\", \"unicode/ICU_SHA\", \"unicode/README.md\", \"unicode/LICENSE\", \"wasm/stdlib-symbols.txt\"]")
add("        headerVisibility: project")
add("      - path: \(checkout("tree-sitter/lib/include"))")
add("        headerVisibility: public")
add("      - path: Support/TreeSitter.h")
add("        headerVisibility: public")
settings([
    ("GCC_C_LANGUAGE_STANDARD", "c11"),
    ("GCC_PREPROCESSOR_DEFINITIONS", "\"$(inherited) _POSIX_C_SOURCE=200112L _DEFAULT_SOURCE=1 _DARWIN_C_SOURCE=1\""),
    ("HEADER_SEARCH_PATHS", "\"$(inherited) \(checkout("tree-sitter/lib/src")) \(checkout("tree-sitter/lib/include"))\""),
])
add()

add("  SwiftTreeSitter:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(checkout("swift-tree-sitter/Sources/SwiftTreeSitter"))")
add("        excludes: [\"Documentation.docc\"]")
add("    dependencies:")
add("      - target: TreeSitter")
settings()
add()

// Only linked, never named in an interface -- but it still has to ship, because both
// CodeEditTextView and CodeEditSourceEditor link against it.
add("  CodeEditTextViewObjC:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(local("CodeEditTextView/Sources/CodeEditTextViewObjC"))")
add("        excludes: [\"include/module.modulemap\"]")
add("        headerVisibility: public")
add("      - path: Support/CodeEditTextViewObjC.h")
add("        headerVisibility: public")
settings()
add()

// --- our modules ----------------------------------------------------------------------------------
// SWIFT_PACKAGE_NAME keeps the `package`-access declarations these modules share resolvable across
// the framework boundary; AccessLevelOnImport enables the `internal import`s that keep the grammars
// out of the public interfaces.
let ourSettings: [(String, String)] = [
    ("SWIFT_PACKAGE_NAME", "DoopEditor"),
    ("OTHER_SWIFT_FLAGS", "\"$(inherited) -enable-experimental-feature AccessLevelOnImport\""),
]

add("  CodeEditTextView:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(local("CodeEditTextView/Sources/CodeEditTextView"))")
add("        excludes: [\"Documentation.docc\"]")
add("    dependencies:")
add("      - target: TextStory")
add("      - target: CodeEditTextViewObjC")
add("      - package: swift-collections")
add("        product: DequeModule")
settings(ourSettings)
add()

add("  CodeEditLanguages:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(local("CodeEditLanguages/Sources/CodeEditLanguages"))")
add("        excludes: [\"Documentation.docc\", \"Resources\"]")
for name in resources {
    // Folder references, so `Resources/tree-sitter-<lang>/<query>.scm` keeps the layout
    // CodeLanguage.queryURL(for:) expects inside the framework bundle.
    add("      - path: \(local("CodeEditLanguages/Sources/CodeEditLanguages/Resources/\(name)"))")
    add("        type: folder")
    add("        buildPhase: resources")
}
add("    dependencies:")
add("      - target: SwiftTreeSitter")
for (product, package) in grammars {
    add("      - package: \(package)")
    add("        product: \(product)")
}
settings(ourSettings + [("OTHER_LDFLAGS", "\"$(inherited) -lc++\"")])
add()

add("  CodeEditSourceEditor:")
add("    type: framework")
add("    platform: macOS")
add("    sources:")
add("      - path: \(local("CodeEditSourceEditor/Sources/CodeEditSourceEditor"))")
add("        excludes: [\"Documentation.docc\"]")
add("    dependencies:")
add("      - target: CodeEditTextView")
add("      - target: CodeEditLanguages")
add("      - target: TextFormation")
add("      - target: CodeEditTextViewObjC")
add("      - package: swift-collections")
add("        product: _RopeModule")
settings(ourSettings)
add()

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: output, atomically: true, encoding: .utf8)
} catch {
    fail("could not write \(output.path): \(error)")
}
print("wrote BinaryDistribution/project.yml (\(grammars.count) grammar products)")
