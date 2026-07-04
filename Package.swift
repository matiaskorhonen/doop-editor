// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DoopEditor",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodeEditSourceEditor", targets: ["CodeEditSourceEditor"]),
        .library(name: "CodeEditTextView", targets: ["CodeEditTextView"]),
        .library(name: "CodeEditLanguages", targets: ["CodeEditLanguages"]),
    ],
    dependencies: [
        // CodeEditTextView deps
        .package(url: "https://github.com/ChimeHQ/TextStory", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.0.0")),
        // CodeEditSourceEditor deps
        .package(url: "https://github.com/ChimeHQ/TextFormation", from: "0.8.2"),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
        // CodeEditLanguages deps
        .package(url: "https://github.com/tree-sitter/swift-tree-sitter.git", exact: "0.10.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", exact: "0.23.3"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c.git", exact: "0.24.2"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-cpp.git", revision: "8b5b49eb196bec7040441bee33b2c9a4838d6967"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp.git", revision: "af29416d729b7a6603101b513604392d8f675e3b"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-css.git", exact: "0.23.2"),
        .package(url: "https://github.com/camdencheek/tree-sitter-dockerfile.git", revision: "971acdd908568b4531b0ba28a445bf0bb720aba5"), // main
        .package(url: "https://github.com/elixir-lang/tree-sitter-elixir.git", revision: "c4f9f5a15ddad8635ba59a5b99c2e9124e74ad91"), // main
        .package(url: "https://github.com/matiaskorhonen/tree-sitter-generic.git", revision: "4a967c7ca3ce6116827ddf090eaa4ef7d10c03df"), // main
        .package(url: "https://github.com/tree-sitter/tree-sitter-go.git", exact: "0.25.0"),
        .package(url: "https://github.com/camdencheek/tree-sitter-go-mod.git", revision: "2e886870578eeba1927a2dc4bd2e2b3f598c5f9a"), // main
        .package(url: "https://github.com/tree-sitter/tree-sitter-haskell.git", revision: "0975ef72fc3c47b530309ca93937d7d143523628"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-html.git", revision: "73a3947324f6efddf9e17c0ea58d454843590cc0"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-java.git", revision: "e10607b45ff745f5f876bfa3e94fbcc6b44bdc11"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", exact: "0.23.1"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-jsdoc.git", exact: "0.23.2"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", exact: "0.24.8"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-julia.git", exact: "0.23.1"),
        .package(url: "https://github.com/fwcd/tree-sitter-kotlin", revision: "c8ac3d2627240160b999a2c100de3babbdb8f419"), // main
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-lua", exact: "0.3.0"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown", exact: "0.5.3"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-objc", revision: "181a81b8f23a2d593e7ab4259981f50122909fda"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-ocaml.git", exact: "0.24.2"),
        .package(url: "https://github.com/tree-sitter-perl/tree-sitter-perl.git", revision: "0390ac6f4e26f5805c9d7d9b950685436faa6359"), // release
        .package(url: "https://github.com/tree-sitter/tree-sitter-php.git", exact: "0.24.2"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", exact: "0.23.6"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-regex.git", exact: "0.25.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ruby.git", revision: "ad907a69da0c8a4f7a943a7fe012712208da6dee"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-rust.git", revision: "77a3747266f4d621d0757825e6b11edcbf991ca5"), // master
        .package(url: "https://github.com/tree-sitter/tree-sitter-scala.git", revision: "4d081d98670ff6e98ca42c085294fc75eec15e1d"), // master
        .package(url: "https://github.com/DerekStride/tree-sitter-sql.git", revision: "851e9cb257ba7c66cc8c14214a31c44d2f1e954e"), // gh-pages
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift.git", revision: "31d17fe7e818a2048c808b5c6fdc2dc792f4f5b5"), // with-generated-files
        .package(url: "https://github.com/cengelbart39/tree-sitter-toml.git", revision: "28db724e8e30920638b46d408c0fbac007ac6a62"), // feature/spm
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript.git", revision: "75b3874edb2dc714fb1fd77a32013d0f8699989f"), // master
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", exact: "0.7.0"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-zig.git", revision: "b0b21e587fb0702d67e276b6ef574cd1c2313c15"), // update
    ],
    targets: [
        // MARK: - CodeEditTextView
        .target(
            name: "CodeEditTextViewObjC",
            path: "CodeEditTextView/Sources/CodeEditTextViewObjC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "CodeEditTextView",
            dependencies: [
                "TextStory",
                .product(name: "Collections", package: "swift-collections"),
                "CodeEditTextViewObjC",
            ],
            path: "CodeEditTextView/Sources/CodeEditTextView"
        ),
        .testTarget(
            name: "CodeEditTextViewTests",
            dependencies: ["CodeEditTextView"],
            path: "CodeEditTextView/Tests/CodeEditTextViewTests"
        ),

        // MARK: - CodeEditLanguages
        .target(
            name: "CodeEditLanguages",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "swift-tree-sitter"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterC", package: "tree-sitter-c"),
                .product(name: "TreeSitterCPP", package: "tree-sitter-cpp"),
                .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
                .product(name: "TreeSitterCSS", package: "tree-sitter-css"),
                .product(name: "TreeSitterDockerfile", package: "tree-sitter-dockerfile"),
                .product(name: "TreeSitterElixir", package: "tree-sitter-elixir"),
                .product(name: "TreeSitterGeneric", package: "tree-sitter-generic"),
                .product(name: "TreeSitterGo", package: "tree-sitter-go"),
                .product(name: "TreeSitterGoMod", package: "tree-sitter-go-mod"),
                .product(name: "TreeSitterHaskell", package: "tree-sitter-haskell"),
                .product(name: "TreeSitterHTML", package: "tree-sitter-html"),
                .product(name: "TreeSitterJava", package: "tree-sitter-java"),
                .product(name: "TreeSitterJavaScript", package: "tree-sitter-javascript"),
                .product(name: "TreeSitterJSDoc", package: "tree-sitter-jsdoc"),
                .product(name: "TreeSitterJSON", package: "tree-sitter-json"),
                .product(name: "TreeSitterJulia", package: "tree-sitter-julia"),
                .product(name: "TreeSitterKotlin", package: "tree-sitter-kotlin"),
                .product(name: "TreeSitterLua", package: "tree-sitter-lua"),
                .product(name: "TreeSitterMarkdown", package: "tree-sitter-markdown"),
                .product(name: "TreeSitterObjc", package: "tree-sitter-objc"),
                .product(name: "TreeSitterOCaml", package: "tree-sitter-ocaml"),
                .product(name: "TreeSitterPerl", package: "tree-sitter-perl"),
                .product(name: "TreeSitterPHP", package: "tree-sitter-php"),
                .product(name: "TreeSitterPython", package: "tree-sitter-python"),
                .product(name: "TreeSitterRegex", package: "tree-sitter-regex"),
                .product(name: "TreeSitterRuby", package: "tree-sitter-ruby"),
                .product(name: "TreeSitterRust", package: "tree-sitter-rust"),
                .product(name: "TreeSitterScala", package: "tree-sitter-scala"),
                .product(name: "TreeSitterSql", package: "tree-sitter-sql"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
                .product(name: "TreeSitterTOML", package: "tree-sitter-toml"),
                .product(name: "TreeSitterTypeScript", package: "tree-sitter-typescript"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
                .product(name: "TreeSitterZig", package: "tree-sitter-zig"),
            ],
            path: "CodeEditLanguages/Sources/CodeEditLanguages",
            resources: [
                .copy("Resources/tree-sitter-bash"),
                .copy("Resources/tree-sitter-c"),
                .copy("Resources/tree-sitter-c-sharp"),
                .copy("Resources/tree-sitter-cpp"),
                .copy("Resources/tree-sitter-css"),
                .copy("Resources/tree-sitter-dockerfile"),
                .copy("Resources/tree-sitter-elixir"),
                .copy("Resources/tree-sitter-generic"),
                .copy("Resources/tree-sitter-go"),
                .copy("Resources/tree-sitter-go-mod"),
                .copy("Resources/tree-sitter-haskell"),
                .copy("Resources/tree-sitter-html"),
                .copy("Resources/tree-sitter-java"),
                .copy("Resources/tree-sitter-javascript"),
                .copy("Resources/tree-sitter-jsdoc"),
                .copy("Resources/tree-sitter-json"),
                .copy("Resources/tree-sitter-julia"),
                .copy("Resources/tree-sitter-kotlin"),
                .copy("Resources/tree-sitter-lua"),
                .copy("Resources/tree-sitter-markdown"),
                .copy("Resources/tree-sitter-markdown-inline"),
                .copy("Resources/tree-sitter-objc"),
                .copy("Resources/tree-sitter-ocaml"),
                .copy("Resources/tree-sitter-perl"),
                .copy("Resources/tree-sitter-php"),
                .copy("Resources/tree-sitter-python"),
                .copy("Resources/tree-sitter-regex"),
                .copy("Resources/tree-sitter-ruby"),
                .copy("Resources/tree-sitter-rust"),
                .copy("Resources/tree-sitter-scala"),
                .copy("Resources/tree-sitter-sql"),
                .copy("Resources/tree-sitter-swift"),
                .copy("Resources/tree-sitter-toml"),
                .copy("Resources/tree-sitter-typescript"),
                .copy("Resources/tree-sitter-yaml"),
                .copy("Resources/tree-sitter-zig"),
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),
        .testTarget(
            name: "CodeEditLanguagesTests",
            dependencies: ["CodeEditLanguages"],
            path: "CodeEditLanguages/Tests/CodeEditLanguagesTests"
        ),

        // MARK: - CodeEditSourceEditor
        .target(
            name: "CodeEditSourceEditor",
            dependencies: [
                "CodeEditTextView",
                "CodeEditLanguages",
                "TextFormation",
            ],
            path: "CodeEditSourceEditor/Sources/CodeEditSourceEditor"
        ),
        .testTarget(
            name: "CodeEditSourceEditorTests",
            dependencies: [
                "CodeEditSourceEditor",
                "CodeEditLanguages",
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ],
            path: "CodeEditSourceEditor/Tests/CodeEditSourceEditorTests"
        ),
    ]
)
