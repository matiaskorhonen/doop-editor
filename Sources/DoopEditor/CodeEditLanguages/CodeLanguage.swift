//
//  CodeLanguage.swift
//  CodeEditTextView/CodeLanguage
//
//  Created by Lukas Pistrol on 25.05.22.
//

import Foundation
internal import TreeSitter
internal import SwiftTreeSitter
internal import TreeSitterAgda
internal import TreeSitterBash
internal import TreeSitterC
internal import TreeSitterCPP
internal import TreeSitterCSharp
internal import TreeSitterCSS
internal import TreeSitterDockerfile
internal import TreeSitterElixir
internal import TreeSitterGeneric
internal import TreeSitterGo
internal import TreeSitterGoMod
internal import TreeSitterHaskell
internal import TreeSitterHTML
internal import TreeSitterJava
internal import TreeSitterJavaScript
internal import TreeSitterJSDoc
internal import TreeSitterJSON
internal import TreeSitterJulia
internal import TreeSitterKotlin
internal import TreeSitterLua
internal import TreeSitterMarkdown
internal import TreeSitterMarkdownInline
internal import TreeSitterObjc
internal import TreeSitterOCaml
internal import TreeSitterPerl
internal import TreeSitterPHP
internal import TreeSitterPython
internal import TreeSitterRegex
internal import TreeSitterRuby
internal import TreeSitterRust
internal import TreeSitterScala
internal import TreeSitterSql
internal import TreeSitterSwift
internal import TreeSitterTOML
internal import TreeSitterTypeScript
internal import TreeSitterTSX
internal import TreeSitterYAML
internal import TreeSitterZig
import RegexBuilder

/// A structure holding metadata for code languages
public struct CodeLanguage {
    internal init(
        id: TreeSitterLanguage,
        tsName: String,
        extensions: Set<String>,
        lineCommentString: String,
        rangeCommentStrings: (String, String),
        documentationCommentStrings: Set<DocumentationComments> = [],
        parentURL: URL? = nil,
        highlights: Set<String>? = nil,
        additionalIdentifiers: Set<String> = []
    ) {
        self.id = id
        self.tsName = tsName
        self.extensions = extensions
        self.lineCommentString = lineCommentString
        self.rangeCommentStrings = rangeCommentStrings
        self.documentationCommentStrings = documentationCommentStrings
        self.parentQueryURL = parentURL
        self.additionalHighlights = highlights
        self.additionalIdentifiers = additionalIdentifiers
    }

    /// The ID of the language
    public let id: TreeSitterLanguage

    /// The display name of the language
    public let tsName: String

    /// A set of file extensions for the language
    ///
    /// In special cases this can also be a file name
    /// (e.g `Dockerfile`, `Makefile`)
    public let extensions: Set<String>

    /// The leading string of a comment line
    public let lineCommentString: String

    /// The leading and trailing string of a multi-line comment
    public let rangeCommentStrings: (String, String)

    /// The leading (and trailing, if there is one) string of a documentation comment
    public let documentationCommentStrings: Set<DocumentationComments>

    /// The query URL of a language this language inherits from. (e.g.: C for C++)
    public let parentQueryURL: URL?

    /// Additional highlight file names (e.g.: JSX for JavaScript)
    public let additionalHighlights: Set<String>?

    /// The query URL for the language if available
    public var queryURL: URL? {
        queryURL()
    }

    /// The bundle's resource URL
    internal var resourceURL: URL? = Bundle.codeEditLanguages.resourceURL

    /// A set of additional identifiers to use for things like shebang matching.
    public let additionalIdentifiers: Set<String>

    /// Whether this language can actually be highlighted: its tree-sitter grammar is linked in and
    /// its highlight query is bundled and compiles.
    ///
    /// Both are baked into the module -- the grammars statically, the `.scm` queries as resources --
    /// so for a given build this is a constant. It is worth asking when a consumer wants to offer
    /// only the languages that will really highlight, and the release's consumer check uses it to
    /// prove a built framework carries both. Compiling a query is expensive; the result comes from
    /// ``TreeSitterModel``'s cache, so repeated calls for the same language are cheap.
    public var isHighlightable: Bool {
        language != nil && TreeSitterModel.shared.query(for: id) != nil
    }

    /// The tree-sitter language for the language if available
    var language: Language? {
        guard let tsLanguage = tsLanguage else { return nil }
        return Language(language: tsLanguage)
    }

    internal func queryURL(for highlights: String = "highlights") -> URL? {
        return resourceURL?
            .appendingPathComponent("tree-sitter-\(tsName)/\(highlights).scm")
    }

    /// Gets the TSLanguage from `tree-sitter`
    private var tsLanguage: OpaquePointer? {
        switch id {
        case .agda:
            return tree_sitter_agda()
        case .bash:
            return tree_sitter_bash()
        case .c:
            return tree_sitter_c()
        case .cpp:
            return tree_sitter_cpp()
        case .cSharp:
            return tree_sitter_c_sharp()
        case .css:
            return tree_sitter_css()
        case .dockerfile:
            return tree_sitter_dockerfile()
        case .elixir:
            return tree_sitter_elixir()
        case .generic:
            return tree_sitter_generic()
        case .go:
            return tree_sitter_go()
        case .goMod:
            return tree_sitter_gomod()
        case .haskell:
            return tree_sitter_haskell()
        case .html:
            return tree_sitter_html()
        case .java:
            return tree_sitter_java()
        case .javascript:
            return tree_sitter_javascript()
        case .jsdoc:
            return tree_sitter_jsdoc()
        case .json:
            return tree_sitter_json()
        case .jsx:
            return tree_sitter_javascript()
        case .julia:
            return tree_sitter_julia()
        case .kotlin:
            return tree_sitter_kotlin()
        case .lua:
            return tree_sitter_lua()
        case .markdown:
            return tree_sitter_markdown()
        case .markdownInline:
            return tree_sitter_markdown_inline()
        case .objc:
            return tree_sitter_objc()
        case .ocaml:
            return tree_sitter_ocaml()
        case .ocamlInterface:
            return tree_sitter_ocaml_interface()
        case .perl:
            return tree_sitter_perl()
        case .php:
            return tree_sitter_php()
        case .python:
            return tree_sitter_python()
        case .regex:
            return tree_sitter_regex()
        case .ruby:
            return tree_sitter_ruby()
        case .rust:
            return tree_sitter_rust()
        case .scala:
            return tree_sitter_scala()
        case .sql:
            return tree_sitter_sql()
        case .swift:
            return tree_sitter_swift()
        case .toml:
            return tree_sitter_toml()
        case .tsx:
            return tree_sitter_tsx()
        case .typescript:
            return tree_sitter_typescript()
        case .yaml:
            return tree_sitter_yaml()
        case .zig:
            return tree_sitter_zig()
        case .plainText:
            return nil
        }
    }
}

extension CodeLanguage: Hashable {
    public static func == (lhs: CodeLanguage, rhs: CodeLanguage) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public enum DocumentationComments: Hashable {
    public static func == (lhs: DocumentationComments, rhs: DocumentationComments) -> Bool {
        switch lhs {
        case .single(let lhsString):
            switch rhs {
            case .single(let rhsString):
                return lhsString == rhsString
            case .pair:
                return false
            }
        case .pair(let lhsPair):
            switch rhs {
            case .single:
                return false
            case .pair(let rhsPair):
                return lhsPair.0 == rhsPair.0 && lhsPair.1 == rhsPair.1
            }
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .single(let string):
            hasher.combine(string)
        case .pair(let pair):
            hasher.combine(pair.0)
            hasher.combine(pair.1)
        }
    }

    case single(String)
    case pair((String, String))
}
