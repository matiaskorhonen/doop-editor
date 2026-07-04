//
//  TreeSitterModel.swift
//  CodeEditTextView/CodeLanguage
//
//  Created by Lukas Pistrol on 25.05.22.
//

import Foundation
import SwiftTreeSitter

/// A singleton class to manage `tree-sitter` queries and keep them in memory.
public class TreeSitterModel {

    /// The singleton/shared instance of ``TreeSitterModel``.
    public static let shared: TreeSitterModel = .init()

    /// Get a query for a specific language
    /// - Parameter language: The language to request the query for.
    /// - Returns: A Query if available. Returns `nil` for not implemented languages
    public func query(for language: TreeSitterLanguage) -> Query? {
        // swiftlint:disable:previous cyclomatic_complexity function_body_length
        switch language {
        case .bash:
            return bashQuery
        case .c:
            return cQuery
        case .cpp:
            return cppQuery
        case .cSharp:
            return cSharpQuery
        case .css:
            return cssQuery
        case .dockerfile:
            return dockerfileQuery
        case .elixir:
            return elixirQuery
        case .generic:
            return genericQuery
        case .go:
            return goQuery
        case .goMod:
            return goModQuery
        case .html:
            return htmlQuery
        case .java:
            return javaQuery
        case .javascript:
            return javascriptQuery
        case .jsdoc:
            return jsdocQuery
        case .json:
            return jsonQuery
        case .jsx:
            return jsxQuery
        case .julia:
            return juliaQuery
        case .kotlin:
            return kotlinQuery
        case .lua:
            return luaQuery
        case .markdown:
            return markdownQuery
        case .markdownInline:
            return markdownInlineQuery
        case .objc:
            return objcQuery
        case .perl:
            return perlQuery
        case .php:
            return phpQuery
        case .python:
            return pythonQuery
        case .regex:
            return regexQuery
        case .ruby:
            return rubyQuery
        case .rust:
            return rustQuery
        case .scala:
            return scalaQuery
        case .sql:
            return sqlQuery
        case .swift:
            return swiftQuery
        case .toml:
            return tomlQuery
        case .tsx:
            return tsxQuery
        case .typescript:
            return typescriptQuery
        case .yaml:
            return yamlQuery
        case .zig:
            return zigQuery
        case .plainText:
            return nil
        }
    }

    /// Query for `Bash` files.
    public private(set) lazy var bashQuery: Query? = {
        return queryFor(.bash)
    }()

    /// Query for `C` files.
    public private(set) lazy var cQuery: Query? = {
        return queryFor(.c)
    }()

    /// Query for `C++` files.
    public private(set) lazy var cppQuery: Query? = {
        return queryFor(.cpp)
    }()

    /// Query for `C#` files.
    public private(set) lazy var cSharpQuery: Query? = {
        return queryFor(.cSharp)
    }()

    /// Query for `CSS` files.
    public private(set) lazy var cssQuery: Query? = {
        return queryFor(.css)
    }()

    /// Query for `Dockerfile` files.
    public private(set) lazy var dockerfileQuery: Query? = {
        return queryFor(.dockerfile)
    }()

    /// Query for `Elixir` files.
    public private(set) lazy var elixirQuery: Query? = {
        return queryFor(.elixir)
    }()

    /// Query for `Generic` files.
    public private(set) lazy var genericQuery: Query? = {
        return queryFor(.generic)
    }()

    /// Query for `Go` files.
    public private(set) lazy var goQuery: Query? = {
        return queryFor(.go)
    }()

    /// Query for `GoMod` files.
    public private(set) lazy var goModQuery: Query? = {
        return queryFor(.goMod)
    }()

    /// Query for `HTML` files.
    public private(set) lazy var htmlQuery: Query? = {
        return queryFor(.html)
    }()

    /// Query for `Java` files.
    public private(set) lazy var javaQuery: Query? = {
        return queryFor(.java)
    }()

    /// Query for `JavaScript` files.
    public private(set) lazy var javascriptQuery: Query? = {
        return queryFor(.javascript)
    }()

    /// Query for `JSDoc` files.
    public private(set) lazy var jsdocQuery: Query? = {
        return queryFor(.jsdoc)
    }()

    /// Query for `JSX` files.
    public private(set) lazy var jsxQuery: Query? = {
        return queryFor(.jsx)
    }()

    /// Query for `JSON` files.
    public private(set) lazy var jsonQuery: Query? = {
        return queryFor(.json)
    }()

    /// Query for `Julia` files.
    public private(set) lazy var juliaQuery: Query? = {
        return queryFor(.julia)
    }()

    /// Query for `Kotlin` files.
    public private(set) lazy var kotlinQuery: Query? = {
        return queryFor(.kotlin)
    }()

    /// Query for `Lua` files.
    public private(set) lazy var luaQuery: Query? = {
        return queryFor(.lua)
    }()

    /// Query for `Markdown` files.
    public private(set) lazy var markdownQuery: Query? = {
        return queryFor(.markdown)
    }()

    /// Query for `Markdown Inline` files.
    public private(set) lazy var markdownInlineQuery: Query? = {
        return queryFor(.markdownInline)
    }()

    /// Query for `Objective C` files.
    public private(set) lazy var objcQuery: Query? = {
        return queryFor(.objc)
    }()

    /// Query for `Perl` files.
    public private(set) lazy var perlQuery: Query? = {
        return queryFor(.perl)
    }()

    /// Query for `PHP` files.
    public private(set) lazy var phpQuery: Query? = {
        return queryFor(.php)
    }()

    /// Query for `Python` files.
    public private(set) lazy var pythonQuery: Query? = {
        return queryFor(.python)
    }()

    /// Query for `Regex` files.
    public private(set) lazy var regexQuery: Query? = {
        return queryFor(.regex)
    }()

    /// Query for `Ruby` files.
    public private(set) lazy var rubyQuery: Query? = {
        return queryFor(.ruby)
    }()

    /// Query for `Rust` files.
    public private(set) lazy var rustQuery: Query? = {
        return queryFor(.rust)
    }()

    /// Query for `Scala` files.
    public private(set) lazy var scalaQuery: Query? = {
        return queryFor(.scala)
    }()

    /// Query for `SQL` files.
    public private(set) lazy var sqlQuery: Query? = {
        return queryFor(.sql)
    }()

    /// Query for `Swift` files.
    public private(set) lazy var swiftQuery: Query? = {
        return queryFor(.swift)
    }()

    /// Query for `TOML` files.
    public private(set) lazy var tomlQuery: Query? = {
        return queryFor(.toml)
    }()

    /// Query for `TSX` files.
    public private(set) lazy var tsxQuery: Query? = {
        return queryFor(.tsx)
    }()

    /// Query for `Typescript` files.
    public private(set) lazy var typescriptQuery: Query? = {
        return queryFor(.typescript)
    }()

    /// Query for `YAML` files.
    public private(set) lazy var yamlQuery: Query? = {
        return queryFor(.yaml)
    }()

    /// Query for `Zig` files.
    public private(set) lazy var zigQuery: Query? = {
        return queryFor(.zig)
    }()

    private func queryFor(_ codeLanguage: CodeLanguage) -> Query? {
        // get the tree-sitter language and query url if available
        guard let language = codeLanguage.language,
              let url = codeLanguage.queryURL else { return nil }

        // Start with the base highlights query
        var queryURLs = [url]

        // Add the parent language query if this language inherits from another
        if let parentURL = codeLanguage.parentQueryURL {
            queryURLs.insert(parentURL, at: 0)
        }

        // Add any additional highlight files (e.g., folds, indents, injections)
        if let additionalHighlights = codeLanguage.additionalHighlights {
            let addURLs = additionalHighlights.compactMap({ codeLanguage.queryURL(for: $0) })
            queryURLs.append(contentsOf: addURLs)
        }

        // Load each query file individually, skipping files that fail to compile.
        // This prevents one bad .scm file from breaking all syntax highlighting.
        return resilientQuery(language: language, fileURLs: queryURLs)
    }

    /// Loads query files individually and combines them, skipping any that fail to compile.
    /// This ensures a single invalid .scm file does not break all highlighting for a language.
    private func resilientQuery(language: Language, fileURLs: [URL]) -> Query? {
        var validQueries: [String] = []

        for url in fileURLs {
            guard let contents = try? String(contentsOf: url) else { continue }
            // Strip nvim-treesitter inheritance directives that aren't understood by tree-sitter
            let stripped = contents
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("; inherits:") }
                .joined(separator: "\n")
            guard let data = stripped.data(using: .utf8) else { continue }

            do {
                // Validate this file compiles on its own against the grammar
                _ = try Query(language: language, data: data)
                validQueries.append(stripped)
            } catch {
                print(
                    "[TreeSitterModel] Warning: skipping \(url.lastPathComponent) — "
                    + "query failed to compile: \(error)"
                )
            }
        }

        guard !validQueries.isEmpty,
              let combined = validQueries.joined(separator: "\n").data(using: .utf8) else {
            return nil
        }

        return try? Query(language: language, data: combined)
    }

    private init() {}
}
