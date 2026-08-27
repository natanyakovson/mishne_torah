import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var halakhot: [MTHalakhah]
    @Query private var settings: [MTReaderSettings]
    @State private var query = ""
    @State private var selectedHalakhahID: UUID?

    private var results: [MTHalakhah] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return halakhot.filter { halakhah in
            halakhah.hebrewText.localizedCaseInsensitiveContains(trimmed)
            || (halakhah.russianText?.localizedCaseInsensitiveContains(trimmed) ?? false)
            || halakhah.reference.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(results, selection: $selectedHalakhahID) { halakhah in
                VStack(alignment: .leading, spacing: 8) {
                    Text(halakhah.reference)
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(SefariaStyle.green)
                    Text(halakhah.searchPreviewText)
                        .lineLimit(2)
                        .font(.body.weight(.regular))
                }
                .padding(.vertical, 8)
                .tag(halakhah.id)
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .searchable(text: $query, prompt: "Поиск по русскому, ивриту или ссылке")
            .navigationTitle("Поиск")
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Введите запрос", systemImage: "magnifyingglass")
                } else if results.isEmpty {
                    ContentUnavailableView("Ничего не найдено", systemImage: "text.magnifyingglass")
                }
            }
        } detail: {
            let selectedHalakhah = results.first { $0.id == selectedHalakhahID }
            if let selectedHalakhah, let chapter = selectedHalakhah.chapter {
                ReaderView(chapter: chapter)
            } else {
                ContentUnavailableView("Выберите результат", systemImage: "doc.text")
            }
        }
    }
}
