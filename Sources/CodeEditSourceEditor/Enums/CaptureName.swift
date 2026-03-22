//
//  CaptureNames.swift
//  CodeEditSourceEditor
//
//  Created by Lukas Pistrol on 16.08.22.
//

/// A collection of possible syntax capture types. Represented by an integer for memory efficiency, and with the
/// ability to convert to and from strings for ease of use with tools.
///
/// This is `Int8` raw representable for memory considerations. In large documents there can be *lots* of these created
/// and passed around, so representing them with a single integer is preferable to a string to save memory.
///
public enum CaptureName: Int8, CaseIterable, Sendable {
    case include
    case constructor
    case keyword
    case boolean
    case `repeat`
    case conditional
    case tag
    case comment
    case variable
    case property
    case function
    case method
    case number
    case float
    case string
    case type
    case parameter
    case typeAlternate
    case variableBuiltin
    case keywordReturn
    case keywordFunction
    case `operator`
    case constant
    case namespace
    case attribute
    case label
    case character
    case preproc

    // MARK: Markdown / Text
    case textTitle
    case textStrong
    case textEmphasis
    case textLiteral
    case textUri
    case textReference
    case punctuationSpecial
    case punctuationDelimiter
    case punctuationBracket
    case stringEscape

    var alternate: CaptureName {
        switch self {
        case .type:
            return .typeAlternate
        default:
            return self
        }
    }

    /// Returns a specific capture name case from a given string.
    /// - Note: See ``CaptureName`` docs for why this enum isn't a raw representable.
    /// - Parameter string: A string to get the capture name from
    /// - Returns: A `CaptureNames` case
    public static func fromString(_ string: String?) -> CaptureName? { // swiftlint:disable:this cyclomatic_complexity
        guard let string else { return nil }
        switch string {
        case "include":
            return .include
        case "constructor":
            return .constructor
        case "keyword":
            return .keyword
        case "boolean":
            return .boolean
        case "repeat":
            return .repeat
        case "conditional":
            return .conditional
        case "tag":
            return .tag
        case "comment":
            return .comment
        case "variable":
            return .variable
        case "property":
            return .property
        case "function":
            return .function
        case "method":
            return .method
        case "number":
            return .number
        case "float":
            return .float
        case "string":
            return .string
        case "type":
            return .type
        case "parameter":
            return .parameter
        case "type_alternate":
            return .typeAlternate
        case "variable.builtin":
            return .variableBuiltin
        case "keyword.return":
            return .keywordReturn
        case "keyword.function":
            return .keywordFunction
        case "keyword.operator", "keyword.directive", "keyword.modifier",
             "keyword.type", "keyword.conditional", "keyword.exception":
            return .keyword
        case "operator":
            return .operator
        case "constant", "constant.builtin":
            return .constant
        case "namespace", "module":
            return .namespace
        case "attribute":
            return .attribute
        case "label":
            return .label
        case "character", "character.special":
            return .character
        case "preproc":
            return .preproc
        case "type.builtin", "type.definition", "type.qualifier":
            return .type
        case "function.builtin", "function.call", "function.macro", "function.special":
            return .function
        case "method.call":
            return .method
        case "variable.member":
            return .property
        case "variable.parameter":
            return .parameter
        case "number.float":
            return .float
        case "string.regex", "string.special":
            return .string
        case "comment.documentation", "comment.doc":
            return .comment

        // MARK: Markdown / Text
        case "text.title":
            return .textTitle
        case "text.strong":
            return .textStrong
        case "text.emphasis":
            return .textEmphasis
        case "text.literal":
            return .textLiteral
        case "text.uri":
            return .textUri
        case "text.reference":
            return .textReference
        case "punctuation.special":
            return .punctuationSpecial
        case "punctuation.delimiter":
            return .punctuationDelimiter
        case "punctuation.bracket":
            return .punctuationBracket
        case "string.escape":
            return .stringEscape
        case "none":
            return nil
        default:
            return nil
        }
    }

    /// See ``CaptureName`` docs for why this enum isn't a raw representable.
    var stringValue: String {
        switch self {
        case .include:
            return "include"
        case .constructor:
            return "constructor"
        case .keyword:
            return "keyword"
        case .boolean:
            return "boolean"
        case .repeat:
            return "`repeat`"
        case .conditional:
            return "conditional"
        case .tag:
            return "tag"
        case .comment:
            return "comment"
        case .variable:
            return "variable"
        case .property:
            return "property"
        case .function:
            return "function"
        case .method:
            return "method"
        case .number:
            return "number"
        case .float:
            return "float"
        case .string:
            return "string"
        case .type:
            return "type"
        case .parameter:
            return "parameter"
        case .typeAlternate:
            return "typeAlternate"
        case .variableBuiltin:
            return "variableBuiltin"
        case .keywordReturn:
            return "keywordReturn"
        case .keywordFunction:
            return "keywordFunction"
        case .operator:
            return "operator"
        case .constant:
            return "constant"
        case .namespace:
            return "namespace"
        case .attribute:
            return "attribute"
        case .label:
            return "label"
        case .character:
            return "character"
        case .preproc:
            return "preproc"
        case .textTitle:
            return "text.title"
        case .textStrong:
            return "text.strong"
        case .textEmphasis:
            return "text.emphasis"
        case .textLiteral:
            return "text.literal"
        case .textUri:
            return "text.uri"
        case .textReference:
            return "text.reference"
        case .punctuationSpecial:
            return "punctuation.special"
        case .punctuationDelimiter:
            return "punctuation.delimiter"
        case .punctuationBracket:
            return "punctuation.bracket"
        case .stringEscape:
            return "string.escape"
        }
    }
}

extension CaptureName: CustomDebugStringConvertible {
    public var debugDescription: String { stringValue }
}
