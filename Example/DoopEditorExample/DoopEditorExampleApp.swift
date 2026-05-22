import SwiftUI

@main
struct DoopEditorExampleApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: DoopEditorExampleDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
