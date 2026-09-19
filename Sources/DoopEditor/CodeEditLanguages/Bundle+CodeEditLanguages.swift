//
//  Bundle+CodeEditLanguages.swift
//  CodeEditLanguages
//

import Foundation

extension Bundle {
    /// The bundle holding `CodeEditLanguages`' tree-sitter query resources.
    ///
    /// `Bundle.module` only exists when the module is built by SwiftPM. When `CodeEditLanguages` is
    /// built as a framework for binary distribution the queries live in the framework's own bundle
    /// instead, so the lookup has to go through `Bundle(for:)`.
    static var codeEditLanguages: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }
}

private final class BundleToken {}
