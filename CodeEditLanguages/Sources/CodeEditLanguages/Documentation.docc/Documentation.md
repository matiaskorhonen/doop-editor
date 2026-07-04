# ``CodeEditLanguages``

A collection of `tree-sitter` languages for syntax highlighting.

## Overview

![logo](codeeditlanguages-logo)

This package depends directly on one SwiftPM grammar package per supported `tree-sitter` language — there is no `xcframework`.

The languages are then served as a ``CodeLanguage``.

## SwiftTreeSitter

This package heavily depends on [SwiftTreeSitter](https://github.com/ChimeHQ/SwiftTreeSitter) by [Matt Massicotte](https://bsky.app/profile/massicotte.org).

## Topics

### Guides

- <doc:Add-Languages>
- <doc:Update-Languages>

### Structs

- ``CodeEditLanguages/CodeLanguage``

### Classes

- ``CodeEditLanguages/TreeSitterModel``

### Enums

- ``CodeEditLanguages/TreeSitterLanguage``
