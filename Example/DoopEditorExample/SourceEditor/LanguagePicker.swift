import SwiftUI
import CodeEditLanguages

struct LanguagePicker: View {
    @Binding var language: CodeLanguage

    var body: some View {
        Picker("Language", selection: $language) {
            ForEach(
                [.default] + CodeLanguage.allLanguages.filter { !$0.extensions.isEmpty },
                id: \.id
            ) { language in
                Text(language.id.rawValue)
                    .tag(language)
            }
        }
        .labelsHidden()
    }
}
