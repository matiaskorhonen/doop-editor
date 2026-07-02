//
//  EditorTheme.swift
//  CodeEditSourceEditor
//
//  Created by Lukas Pistrol on 29.05.22.
//

import SwiftUI

/// A collection of attributes used for syntax highlighting and other colors for the editor.
///
/// Attributes of a theme that do not apply to text (background, line highlight, gutter) are a single `NSColor` for
/// simplicity. All other attributes use the ``EditorTheme/Attribute`` type to store
public struct EditorTheme: Equatable {
    /// Represents attributes that can be applied to style text.
    public struct Attribute: Equatable, Hashable, Sendable {
        public let color: NSColor
        public let bold: Bool
        public let italic: Bool
        public let underline: Bool

        public init(color: NSColor, bold: Bool = false, italic: Bool = false, underline: Bool = false) {
            self.color = color
            self.bold = bold
            self.italic = italic
            self.underline = underline
        }
    }

    public var text: Attribute
    public var insertionPoint: NSColor
    public var invisibles: Attribute
    public var background: NSColor
    public var lineHighlight: NSColor
    public var selection: NSColor

    /// The gutter's background color. Defaults to ``background`` when `nil`.
    public var gutterBackground: NSColor?
    /// A vertical divider drawn between the gutter and the text view. No divider is drawn when `nil`.
    public var gutterDividerColor: NSColor?
    public var keywords: Attribute
    public var commands: Attribute
    public var types: Attribute
    public var attributes: Attribute
    public var variables: Attribute
    public var values: Attribute
    public var numbers: Attribute
    public var strings: Attribute
    public var characters: Attribute
    public var comments: Attribute

    // MARK: Extended Capture Attributes
    public var operators: Attribute
    public var constants: Attribute
    public var namespaces: Attribute
    public var labels: Attribute
    public var preproc: Attribute
    public var stringEscape: Attribute

    // MARK: Markdown / Text Attributes
    public var textTitle: Attribute
    public var textStrong: Attribute
    public var textEmphasis: Attribute
    public var textLiteral: Attribute
    public var textUri: Attribute
    public var textReference: Attribute
    public var punctuationSpecial: Attribute
    public var punctuationDelimiter: Attribute
    public var punctuationBracket: Attribute

    public init(
        text: Attribute,
        insertionPoint: NSColor,
        invisibles: Attribute,
        background: NSColor,
        lineHighlight: NSColor,
        selection: NSColor,
        gutterBackground: NSColor? = nil,
        gutterDividerColor: NSColor? = nil,
        keywords: Attribute,
        commands: Attribute,
        types: Attribute,
        attributes: Attribute,
        variables: Attribute,
        values: Attribute,
        numbers: Attribute,
        strings: Attribute,
        characters: Attribute,
        comments: Attribute,
        operators: Attribute? = nil,
        constants: Attribute? = nil,
        namespaces: Attribute? = nil,
        labels: Attribute? = nil,
        preproc: Attribute? = nil,
        stringEscape: Attribute? = nil,
        textTitle: Attribute? = nil,
        textStrong: Attribute? = nil,
        textEmphasis: Attribute? = nil,
        textLiteral: Attribute? = nil,
        textUri: Attribute? = nil,
        textReference: Attribute? = nil,
        punctuationSpecial: Attribute? = nil,
        punctuationDelimiter: Attribute? = nil,
        punctuationBracket: Attribute? = nil
    ) {
        self.text = text
        self.insertionPoint = insertionPoint
        self.invisibles = invisibles
        self.background = background
        self.lineHighlight = lineHighlight
        self.selection = selection
        self.gutterBackground = gutterBackground
        self.gutterDividerColor = gutterDividerColor
        self.keywords = keywords
        self.commands = commands
        self.types = types
        self.attributes = attributes
        self.variables = variables
        self.values = values
        self.numbers = numbers
        self.strings = strings
        self.characters = characters
        self.comments = comments

        self.operators = operators ?? keywords
        self.constants = constants ?? values
        self.namespaces = namespaces ?? types
        self.labels = labels ?? variables
        self.preproc = preproc ?? keywords
        self.stringEscape = stringEscape ?? strings

        self.textTitle = textTitle ?? Attribute(color: keywords.color, bold: true)
        self.textStrong = textStrong ?? Attribute(color: text.color, bold: true)
        self.textEmphasis = textEmphasis ?? Attribute(color: text.color, italic: true)
        self.textLiteral = textLiteral ?? strings
        self.textUri = textUri ?? Attribute(color: values.color, underline: true)
        self.textReference = textReference ?? types
        self.punctuationSpecial = punctuationSpecial ?? keywords
        self.punctuationDelimiter = punctuationDelimiter ?? text
        self.punctuationBracket = punctuationBracket ?? text
    }

    /// Maps a capture type to the attributes for that capture determined by the theme.
    /// - Parameter capture: The capture to map to.
    /// - Returns: Theme attributes for the capture.
    private func mapCapture(_ capture: CaptureName?) -> Attribute {
        switch capture {
        case .include, .constructor, .keyword, .boolean, .variableBuiltin,
                .keywordReturn, .keywordFunction, .repeat, .conditional, .tag:
            return keywords
        case .comment: return comments
        case .variable, .property: return variables
        case .function, .method: return variables
        case .number, .float: return numbers
        case .string: return strings
        case .type: return types
        case .parameter: return variables
        case .typeAlternate, .attribute: return attributes
        case .character: return characters
        case .operator: return operators
        case .constant: return constants
        case .namespace: return namespaces
        case .label: return labels
        case .preproc: return preproc
        case .stringEscape: return stringEscape
        case .textTitle: return textTitle
        case .textStrong: return textStrong
        case .textEmphasis: return textEmphasis
        case .textLiteral: return textLiteral
        case .textUri: return textUri
        case .textReference: return textReference
        case .punctuationSpecial: return punctuationSpecial
        case .punctuationDelimiter: return punctuationDelimiter
        case .punctuationBracket: return punctuationBracket
        default: return text
        }
    }

    /// Get the color from ``theme`` for the specified capture name.
    /// - Parameter capture: The capture name
    /// - Returns: A `NSColor`
    func colorFor(_ capture: CaptureName?) -> NSColor {
        return mapCapture(capture).color
    }

    /// Returns the correct font with attributes (bold and italics) for a given capture name.
    /// - Parameters:
    ///   - capture: The capture name.
    ///   - font: The font to add attributes to.
    /// - Returns: A new font that has the correct attributes for the capture.
    func fontFor(for capture: CaptureName?, from font: NSFont) -> NSFont {
        let attributes = mapCapture(capture)
        guard attributes.bold || attributes.italic else {
            return font
        }

        var font = font

        if attributes.bold {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }

        if attributes.italic {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        return font
    }

    /// Returns the underline style for a given capture name.
    /// - Parameter capture: The capture name.
    /// - Returns: The underline style to apply, or `0` for no underline.
    func underlineStyleFor(_ capture: CaptureName?) -> NSUnderlineStyle {
        mapCapture(capture).underline ? .single : []
    }
}
