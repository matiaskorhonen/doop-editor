#!/usr/bin/env swift
//
// Generate the XcodeGen spec used to build DoopEditor's distributable XCFrameworks.
//
// The spec is derived from the package itself so it cannot drift from the source build: the
// grammar products come from SwiftPM's parsed manifest (`swift package dump-package`), and every
// package is pinned to the exact revision in Package.resolved.
//
// It is written as JSON through Encodable types rather than templated text, so values are always
// escaped correctly. XcodeGen reads JSON specs as well as YAML; see
// https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
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
let output = outputDirectory.appendingPathComponent("project.json")

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

// MARK: - XcodeGen spec

struct Spec: Encodable {
    struct Options: Encodable {
        let deploymentTarget: [String: String]
        let createIntermediateGroups: Bool
        let defaultConfig: String
    }

    let name: String
    let options: Options
    let configs: [String: String]
    let settings: Settings
    let packages: [String: Package]
    let targets: [String: Target]
}

struct Settings: Encodable {
    let base: [String: String]
}

struct Package: Encodable {
    let url: String
    let revision: String
}

struct Target: Encodable {
    /// `framework` ships as its own XCFramework; `library.static` is absorbed into whichever
    /// framework links it, and so never reaches a consumer.
    let type: String
    let platform = "macOS"
    let sources: [Source]
    let dependencies: [Dependency]?
    let settings: Settings

    init(type: String = "framework", sources: [Source], dependencies: [Dependency] = [], settings: Settings) {
        self.type = type
        self.sources = sources
        self.dependencies = dependencies.isEmpty ? nil : dependencies
        self.settings = settings
    }
}

struct Source: Encodable {
    let path: String
    var excludes: [String]?
    var headerVisibility: String?
    var type: String?
    var buildPhase: String?
}

enum Dependency: Encodable {
    case target(String)
    /// A `library.static` target, which XcodeGen leaves out of the link phase unless `link` says
    /// otherwise -- the symbols are absorbed into this target's binary, so it must be linked.
    case staticTarget(String)
    case package(String, product: String)

    private enum CodingKeys: String, CodingKey {
        case target, package, product, link
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .target(let name):
            try container.encode(name, forKey: .target)
        case .staticTarget(let name):
            try container.encode(name, forKey: .target)
            try container.encode(true, forKey: .link)
        case .package(let package, let product):
            try container.encode(package, forKey: .package)
            try container.encode(product, forKey: .product)
        }
    }
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
func resolvedRevisions() -> [String: Package] {
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
    return Dictionary(uniqueKeysWithValues: resolved.pins.map {
        ($0.identity, Package(url: $0.location, revision: $0.state.revision))
    })
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

// MARK: - Settings

/// Per-target settings.
///
/// SKIP_INSTALL has to be set per target: XcodeGen writes `SKIP_INSTALL = YES` at the target level
/// for framework targets, which overrides the project-level value, and an archive with SKIP_INSTALL
/// on contains no framework to turn into an XCFramework.
///
/// These belong here rather than on the xcodebuild command line, because command-line settings also
/// apply to the SwiftPM dependencies -- and swift-collections does not compile with library
/// evolution enabled.
func targetSettings(_ extra: [String: String] = [:]) -> Settings {
    Settings(base: ["SKIP_INSTALL": "NO"].merging(extra) { _, new in new })
}

/// Settings for a target that is absorbed into the framework linking it rather than shipped.
///
/// It must not install (there is no product to package), and it doesn't need library evolution:
/// nothing outside the framework that absorbs it ever imports it, and a resilient static library
/// would only add dispatch overhead. That is how the SwiftPM package targets are built too.
func staticSettings(_ extra: [String: String] = [:]) -> Settings {
    Settings(base: [
        "SKIP_INSTALL": "YES",
        "BUILD_LIBRARY_FOR_DISTRIBUTION": "NO",
    ].merging(extra) { _, new in new })
}

/// SWIFT_PACKAGE_NAME keeps the `package`-access declarations our three modules share resolvable
/// across the framework boundary; AccessLevelOnImport enables the `internal import`s that keep the
/// grammars out of the public interfaces.
let ourSettings: [String: String] = [
    "SWIFT_PACKAGE_NAME": "DoopEditor",
    "OTHER_SWIFT_FLAGS": "$(inherited) -enable-experimental-feature AccessLevelOnImport",
]

// MARK: - Spec

let grammars = grammarProducts()
let revisions = resolvedRevisions()
let resources = languageResources()

func pin(_ identity: String) -> Package {
    guard let pin = revisions[identity] else { fail("\(identity) is not pinned in Package.resolved") }
    return pin
}

var packages: [String: Package] = [:]
for package in Set(grammars.map(\.package)).union(["swift-collections"]) {
    packages[package] = pin(package)
}

let docc = ["Documentation.docc"]

var targets: [String: Target] = [:]

// --- dependency layer ---------------------------------------------------------------------------

// TextStory re-exports TSYTextStorage from its `Internal` ObjC target through a public typealias, so
// `Internal` lands in TextStory's interface and has to ship under that name.
targets["Internal"] = Target(
    sources: [
        Source(path: checkout("TextStory/Sources/Internal"), headerVisibility: "public"),
        Source(path: "Support/Internal.h", headerVisibility: "public"),
    ],
    settings: targetSettings()
)

targets["Rearrange"] = Target(
    sources: [Source(path: checkout("Rearrange/Sources/Rearrange"), excludes: docc)],
    settings: targetSettings()
)

targets["TextStory"] = Target(
    sources: [Source(path: checkout("TextStory/Sources/TextStory"), excludes: docc)],
    dependencies: [.target("Internal"), .target("Rearrange")],
    settings: targetSettings()
)

// Absorbed into CodeEditSourceEditor, the only module that uses it: its types reach no public
// interface, so consumers never need to import it.
targets["TextFormation"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("TextFormation/Sources/TextFormation"), excludes: docc)],
    dependencies: [.target("TextStory"), .target("Rearrange")],
    settings: staticSettings()
)

// Mirrors the tree-sitter package's own C target settings (path lib, sources src, public headers
// include, and the POSIX feature defines it needs).
targets["TreeSitter"] = Target(
    sources: [
        Source(
            path: checkout("tree-sitter/lib/src"),
            excludes: ["lib.c", "unicode/ICU_SHA", "unicode/README.md", "unicode/LICENSE", "wasm/stdlib-symbols.txt"],
            headerVisibility: "project"
        ),
        Source(path: checkout("tree-sitter/lib/include"), headerVisibility: "public"),
        Source(path: "Support/TreeSitter.h", headerVisibility: "public"),
    ],
    settings: targetSettings([
        "GCC_C_LANGUAGE_STANDARD": "c11",
        "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited) _POSIX_C_SOURCE=200112L _DEFAULT_SOURCE=1 _DARWIN_C_SOURCE=1",
        "HEADER_SEARCH_PATHS": "$(inherited) \(checkout("tree-sitter/lib/src")) \(checkout("tree-sitter/lib/include"))",
    ])
)

targets["SwiftTreeSitter"] = Target(
    sources: [Source(path: checkout("swift-tree-sitter/Sources/SwiftTreeSitter"), excludes: docc)],
    dependencies: [.target("TreeSitter")],
    settings: targetSettings()
)

// Absorbed into CodeEditTextView, now the only module that imports it: CodeEditSourceEditor's gutter
// goes through `CGContext.setHiddenFontSmoothingStyle(_:)` instead. A static library has no module of
// its own, so `internal import CodeEditTextViewObjC` resolves against the package's checked-in module
// map, passed to the importing target below.
targets["CodeEditTextViewObjC"] = Target(
    type: "library.static",
    sources: [
        Source(
            path: local("CodeEditTextView/Sources/CodeEditTextViewObjC"),
            excludes: ["include/module.modulemap"],
            headerVisibility: "project"
        )
    ],
    settings: staticSettings()
)

/// The module map of the Obj-C shim above, as an absolute path for the compiler.
let objcModuleMap = "$(SRCROOT)/" + local("CodeEditTextView/Sources/CodeEditTextViewObjC/include/module.modulemap")

// --- our modules ----------------------------------------------------------------------------------

targets["CodeEditTextView"] = Target(
    sources: [Source(path: local("CodeEditTextView/Sources/CodeEditTextView"), excludes: docc)],
    dependencies: [
        .target("TextStory"),
        .staticTarget("CodeEditTextViewObjC"),
    ],
    settings: targetSettings(ourSettings.merging([
        "OTHER_SWIFT_FLAGS": "\(ourSettings["OTHER_SWIFT_FLAGS"]!) -Xcc -fmodule-map-file=\(objcModuleMap)",
    ]) { _, new in new })
)

targets["CodeEditLanguages"] = Target(
    sources: [Source(path: local("CodeEditLanguages/Sources/CodeEditLanguages"), excludes: docc + ["Resources"])]
        // Folder references, so `Resources/tree-sitter-<lang>/<query>.scm` keeps the layout
        // CodeLanguage.queryURL(for:) expects inside the framework bundle.
        + resources.map { name in
            Source(
                path: local("CodeEditLanguages/Sources/CodeEditLanguages/Resources/\(name)"),
                type: "folder",
                buildPhase: "resources"
            )
        },
    dependencies: [.target("SwiftTreeSitter")] + grammars.map { .package($0.package, product: $0.product) },
    settings: targetSettings(ourSettings.merging(["OTHER_LDFLAGS": "$(inherited) -lc++"]) { _, new in new })
)

targets["CodeEditSourceEditor"] = Target(
    sources: [Source(path: local("CodeEditSourceEditor/Sources/CodeEditSourceEditor"), excludes: docc)],
    dependencies: [
        .target("CodeEditTextView"),
        .target("CodeEditLanguages"),
        .staticTarget("TextFormation"),
        .package("swift-collections", product: "_RopeModule"),
    ],
    settings: targetSettings(ourSettings)
)

let spec = Spec(
    name: "DoopEditorBinary",
    options: .init(deploymentTarget: ["macOS": "13.0"], createIntermediateGroups: true, defaultConfig: "Release"),
    configs: ["Release": "release"],
    settings: Settings(base: [
        // Emits the .swiftinterface that makes the binaries usable from a different compiler than
        // the one that built them.
        "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES",
        "SKIP_INSTALL": "NO",
        "DYLIB_INSTALL_NAME_BASE": "@rpath",
        "MACOSX_DEPLOYMENT_TARGET": "13.0",
        "ARCHS": "arm64 x86_64",
        "ONLY_ACTIVE_ARCH": "NO",
        "SWIFT_VERSION": "5.10",
        "DEFINES_MODULE": "YES",
        "CODE_SIGN_IDENTITY": "",
        "CODE_SIGNING_REQUIRED": "NO",
        "CODE_SIGNING_ALLOWED": "NO",
        "SWIFT_INSTALL_OBJC_HEADER": "NO",
    ]),
    packages: packages,
    targets: targets
)

let encoder = JSONEncoder()
// Sorted keys keep the file stable between runs, so a regenerated spec only differs when an input did.
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    try (encoder.encode(spec) + Data("\n".utf8)).write(to: output, options: .atomic)
} catch {
    fail("could not write \(output.path): \(error)")
}
print("wrote BinaryDistribution/project.json (\(grammars.count) grammar products)")
