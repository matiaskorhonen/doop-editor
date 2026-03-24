// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CodeEditLanguages",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CodeEditLanguages",
            targets: ["CodeEditLanguages"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter.git", exact: "0.10.0"),

        // Tree-sitter grammars
        // Packages pinned to last versions compatible with ChimeHQ/SwiftTreeSitter identity.
        // Newer versions use tree-sitter/swift-tree-sitter URL which causes SPM identity
        // mismatch in their test targets on Swift 6.x.
        .package(url: "https://github.com/tree-sitter/tree-sitter-agda.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-bash.git", exact: "0.23.3"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c.git", exact: "0.23.6"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-cpp.git", exact: "0.23.4"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-c-sharp.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-css.git", exact: "0.23.2"),
        // TODO: tree-sitter-dart has an SSH submodule that breaks SPM checkout
        // .package(url: "https://github.com/UserNobody14/tree-sitter-dart.git", branch: "master"),
        .package(url: "https://github.com/camdencheek/tree-sitter-dockerfile.git", branch: "main"),
        .package(url: "https://github.com/elixir-lang/tree-sitter-elixir.git", branch: "main"),
        .package(url: "https://github.com/matiaskorhonen/tree-sitter-generic.git", branch: "main"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-go.git", exact: "0.23.4"),
        .package(url: "https://github.com/camdencheek/tree-sitter-go-mod.git", branch: "main"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-haskell.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-html.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-java.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-javascript.git", exact: "0.23.1"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-jsdoc.git", exact: "0.23.2"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-json.git", exact: "0.24.8"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-julia.git", exact: "0.23.1"),
        .package(url: "https://github.com/fwcd/tree-sitter-kotlin", branch: "main"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-lua", exact: "0.3.0"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-markdown", exact: "0.5.1"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-objc", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ocaml.git", exact: "0.24.0"),
        .package(url: "https://github.com/tree-sitter-perl/tree-sitter-perl.git", branch: "release"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-php.git", exact: "0.23.12"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-python.git", exact: "0.23.6"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-regex.git", exact: "0.24.3"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-ruby.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-rust.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-scala.git", branch: "master"),
        .package(url: "https://github.com/DerekStride/tree-sitter-sql.git", branch: "gh-pages"),
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift.git", branch: "with-generated-files"),
        .package(url: "https://github.com/cengelbart39/tree-sitter-toml.git", branch: "feature/spm"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-typescript.git", branch: "master"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-verilog.git", exact: "1.0.3"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", exact: "0.7.0"),
        .package(url: "https://github.com/tree-sitter-grammars/tree-sitter-zig.git", exact: "1.1.2"),
    ],
    targets: [
        .target(
            name: "CodeEditLanguages",
            dependencies: [
                "SwiftTreeSitter",
                .product(name: "TreeSitterAgda", package: "tree-sitter-agda"),
                .product(name: "TreeSitterBash", package: "tree-sitter-bash"),
                .product(name: "TreeSitterC", package: "tree-sitter-c"),
                .product(name: "TreeSitterCPP", package: "tree-sitter-cpp"),
                .product(name: "TreeSitterCSharp", package: "tree-sitter-c-sharp"),
                .product(name: "TreeSitterCSS", package: "tree-sitter-css"),
                // .product(name: "TreeSitterDart", package: "tree-sitter-dart"),
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
                .product(name: "TreeSitterVerilog", package: "tree-sitter-verilog"),
                .product(name: "TreeSitterYAML", package: "tree-sitter-yaml"),
                .product(name: "TreeSitterZig", package: "tree-sitter-zig"),
            ],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),

        .testTarget(
            name: "CodeEditLanguagesTests",
            dependencies: ["CodeEditLanguages"]
        ),
    ]
)
