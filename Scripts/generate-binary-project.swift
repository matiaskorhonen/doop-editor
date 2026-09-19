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
    /// Built, and its module put on the search path, but deliberately not linked: its symbols
    /// are already inside another archive this target links. See the note above the targets.
    case moduleTarget(String)
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
        case .moduleTarget(let name):
            try container.encode(name, forKey: .target)
            try container.encode(false, forKey: .link)
        case .package(let package, let product):
            try container.encode(package, forKey: .package)
            try container.encode(product, forKey: .product)
        }
    }
}

// MARK: - Package inputs

/// (product, package identity) for each tree-sitter grammar the DoopEditor target links.
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
          let languages = manifest.targets.first(where: { $0.name == "DoopEditor" })
    else { fail("could not read the DoopEditor target from the manifest") }

    return languages.dependencies.compactMap { dependency in
        guard let product = dependency.product, product.count >= 2,
              let name = product[0], let package = product[1],
              // Every grammar comes from a `tree-sitter-<lang>` package. SwiftTreeSitter and
              // _RopeModule are product dependencies of the same target and are declared
              // explicitly below, so match on the package identity rather than excluding by name.
              package.hasPrefix("tree-sitter-")
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
    let base = root.appendingPathComponent("Sources/DoopEditor/CodeEditLanguages/Resources")
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

/// AccessLevelOnImport enables the `internal import`s that keep the grammars, SwiftTreeSitter,
/// TextStory and TextFormation out of the public interface.
let ourSettings: [String: String] = [
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

// MARK: - Module maps for the C and Obj-C dependencies
//
// A `library.static` target has no module of its own, so Swift cannot `import` it without a module
// map. The Obj-C shim in this repository has one checked in; the two that come out of dependency
// checkouts get one written here, naming the header by absolute path -- the checkout location
// differs per machine, so these cannot be checked in.

func writeModuleMap(_ module: String, header: String) -> String {
    let path = outputDirectory.appendingPathComponent("\(module).modulemap")
    let contents = """
        // Generated by Scripts/generate-binary-project.swift -- do not edit by hand.
        module \(module) {
            header "\(header)"
            export *
        }

        """
    do {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: path, options: .atomic)
    } catch {
        fail("could not write \(path.path): \(error)")
    }
    return "$(SRCROOT)/\(module).modulemap"
}

func absoluteCheckout(_ path: String) -> String {
    root.appendingPathComponent(".build/checkouts/\(path)").path
}

let treeSitterModuleMap = writeModuleMap("TreeSitter", header: absoluteCheckout("tree-sitter/lib/include/tree_sitter/api.h"))
let internalModuleMap = writeModuleMap("Internal", header: absoluteCheckout("TextStory/Sources/Internal/TSYTextStorage.h"))
let objcModuleMap = "$(SRCROOT)/" + local("Sources/CodeEditTextViewObjC/include/module.modulemap")

/// Passes a module map to a target's Swift compile, so an `import` of a static library resolves.
func withModuleMaps(_ settings: [String: String], _ maps: String...) -> [String: String] {
    let flags = maps.map { "-Xcc -fmodule-map-file=\($0)" }.joined(separator: " ")
    let existing = settings["OTHER_SWIFT_FLAGS"] ?? "$(inherited)"
    return settings.merging(["OTHER_SWIFT_FLAGS": "\(existing) \(flags)"]) { _, new in new }
}

// MARK: - Targets
//
// Exactly one target is a framework. Everything else is a `library.static` absorbed into it, which
// is possible because DoopEditor is a single module whose public interface names none of them -- see
// BINARY_DISTRIBUTION.md.
//
// **Each static library must be linked exactly once.** Xcode copies a static target's static
// dependencies into its own archive, so `libTextFormation.a` already contains TextStory, Rearrange
// and Internal. Linking any of those again alongside it gives several hundred duplicate symbols.
// The rule: link only the outermost archive of each chain, and depend on the rest `moduleTarget`,
// which builds them and puts their modules on the search path without linking them.
//
//     TextFormation -> TextStory -> { Internal, Rearrange }
//     SwiftTreeSitter -> TreeSitter
//     CodeEditTextViewObjC

var targets: [String: Target] = [:]

// --- absorbed dependencies ------------------------------------------------------------------------

targets["Internal"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("TextStory/Sources/Internal"), headerVisibility: "project")],
    settings: staticSettings()
)

targets["Rearrange"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("Rearrange/Sources/Rearrange"), excludes: docc)],
    settings: staticSettings()
)

targets["TextStory"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("TextStory/Sources/TextStory"), excludes: docc)],
    dependencies: [.staticTarget("Internal"), .staticTarget("Rearrange")],
    settings: staticSettings(withModuleMaps([:], internalModuleMap))
)

// TextStory re-exports its Obj-C `Internal` target through a public typealias, so anything importing
// TextStory needs that module map too.
targets["TextFormation"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("TextFormation/Sources/TextFormation"), excludes: docc)],
    dependencies: [.staticTarget("TextStory"), .moduleTarget("Rearrange")],
    settings: staticSettings(withModuleMaps([:], internalModuleMap))
)

// Mirrors the tree-sitter package's own C target settings (path lib, sources src, headers include,
// and the POSIX feature defines it needs).
targets["TreeSitter"] = Target(
    type: "library.static",
    sources: [
        Source(
            path: checkout("tree-sitter/lib/src"),
            excludes: ["lib.c", "unicode/ICU_SHA", "unicode/README.md", "unicode/LICENSE", "wasm/stdlib-symbols.txt"],
            headerVisibility: "project"
        ),
        Source(path: checkout("tree-sitter/lib/include"), headerVisibility: "project"),
    ],
    settings: staticSettings([
        "GCC_C_LANGUAGE_STANDARD": "c11",
        "GCC_PREPROCESSOR_DEFINITIONS": "$(inherited) _POSIX_C_SOURCE=200112L _DEFAULT_SOURCE=1 _DARWIN_C_SOURCE=1",
        "HEADER_SEARCH_PATHS": "$(inherited) \(absoluteCheckout("tree-sitter/lib/src")) \(absoluteCheckout("tree-sitter/lib/include"))",
    ])
)

targets["SwiftTreeSitter"] = Target(
    type: "library.static",
    sources: [Source(path: checkout("swift-tree-sitter/Sources/SwiftTreeSitter"), excludes: docc)],
    dependencies: [.staticTarget("TreeSitter")],
    settings: staticSettings(withModuleMaps([:], treeSitterModuleMap))
)

targets["CodeEditTextViewObjC"] = Target(
    type: "library.static",
    sources: [
        Source(
            path: local("Sources/CodeEditTextViewObjC"),
            excludes: ["include/module.modulemap"],
            headerVisibility: "project"
        )
    ],
    settings: staticSettings()
)

// --- the one framework ----------------------------------------------------------------------------

targets["DoopEditor"] = Target(
    sources: [
        Source(path: local("Sources/DoopEditor"), excludes: docc + ["CodeEditLanguages/Resources"]),
    ]
        // Folder references, so `CodeEditLanguages/Resources/tree-sitter-<lang>/<query>.scm` keeps
        // the layout `CodeLanguage.queryURL` expects inside the framework bundle.
        + resources.map { name in
            Source(
                path: local("Sources/DoopEditor/CodeEditLanguages/Resources/\(name)"),
                type: "folder",
                buildPhase: "resources"
            )
        },
    dependencies: [
        .staticTarget("TextFormation"),
        .staticTarget("SwiftTreeSitter"),
        .staticTarget("CodeEditTextViewObjC"),
        // Linked above, through the archives that already contain them.
        .moduleTarget("TextStory"),
        .moduleTarget("Rearrange"),
        .moduleTarget("Internal"),
        .moduleTarget("TreeSitter"),
        .package("swift-collections", product: "_RopeModule"),
    ] + grammars.map { .package($0.package, product: $0.product) },
    settings: targetSettings(withModuleMaps(ourSettings, objcModuleMap, treeSitterModuleMap, internalModuleMap)
        .merging(["OTHER_LDFLAGS": "$(inherited) -lc++"]) { _, new in new })
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
