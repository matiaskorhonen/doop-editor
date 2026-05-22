import SwiftUI
import UniformTypeIdentifiers

struct DoopEditorExampleDocument: FileDocument, @unchecked Sendable {
    enum DocumentError: Error {
        case failedToEncode
    }

    var text: NSTextStorage

    init(text: NSTextStorage = NSTextStorage(string: "")) {
        self.text = text
    }

    static var readableContentTypes: [UTType] { [.item] }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var nsString: NSString?
        NSString.stringEncoding(
            for: data,
            encodingOptions: [
                .allowLossyKey: false,
                .suggestedEncodingsKey: [NSUTF8StringEncoding],
                .useOnlySuggestedEncodingsKey: true
            ],
            convertedString: &nsString,
            usedLossyConversion: nil
        )
        if let nsString {
            self.text = NSTextStorage(string: nsString as String)
        } else {
            fatalError("Failed to read file")
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = (text.string as NSString?)?.data(using: NSUTF8StringEncoding) else {
            throw DocumentError.failedToEncode
        }
        return .init(regularFileWithContents: data)
    }
}
