import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @State private var query = ""
    @State private var results: [MTHalakhah] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var navigationResetID = UUID()

    var body: some View {
        NavigationStack {
            List(results) { halakhah in
                NavigationLink {
                    if let chapter = halakhah.chapter {
                        ReaderView(chapter: chapter)
                    } else {
                        ContentUnavailableView("Глава не найдена", systemImage: "doc.text")
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(halakhah.reference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SefariaStyle.green)
                        Text(highlightedPreview(for: halakhah))
                            .lineLimit(2)
                            .font(.title3.weight(.regular))
                    }
                    .padding(.vertical, 8)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .searchable(text: $query, prompt: "Поиск по русскому, ивриту или ссылке")
            .navigationTitle("Поиск")
            .homeNavigationButton()
            .overlay {
                if isSearching {
                    ProgressView("Ищу...")
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Введите запрос", systemImage: "magnifyingglass")
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                    ContentUnavailableView("Введите минимум 2 буквы", systemImage: "text.magnifyingglass")
                } else if results.isEmpty {
                    ContentUnavailableView("Ничего не найдено", systemImage: "text.magnifyingglass")
                }
            }
            .onChange(of: query) {
                scheduleSearch()
            }
            .onSubmit(of: .search) {
                searchTask?.cancel()
                performSearch()
            }
        }
        .id(navigationResetID)
        .onReceive(NotificationCenter.default.publisher(for: .returnToLibraryRoot)) { _ in
            navigationResetID = UUID()
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                performSearch()
            }
        }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        do {
            let descriptor = FetchDescriptor<MTHalakhah>()
            let allHalakhot = try modelContext.fetch(descriptor)
            results = Array(allHalakhot.lazy.filter { halakhah in
                halakhah.searchableText.localizedCaseInsensitiveContains(trimmed)
            }.prefix(120))
        } catch {
            results = []
        }

        isSearching = false
    }

    private func highlightedPreview(for halakhah: MTHalakhah) -> AttributedString {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = searchPreview(for: halakhah, query: trimmed)
        var attributed = AttributedString(preview)

        guard trimmed.count >= 2 else {
            return attributed
        }

        var searchStart = preview.startIndex
        while searchStart < preview.endIndex,
              let range = preview.range(
                  of: trimmed,
                  options: [.caseInsensitive, .diacriticInsensitive],
                  range: searchStart..<preview.endIndex
            ) {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor = HighlightColor.yellow.color.opacity(0.45)
                attributed[attributedRange].foregroundColor = .red
            }
            searchStart = range.upperBound
        }

        return attributed
    }

    private func searchPreview(for halakhah: MTHalakhah, query: String) -> String {
        let candidates = [
            halakhah.russianText ?? "",
            halakhah.hebrewText,
            halakhah.reference,
            halakhah.notes.joined(separator: " ")
        ]

        guard let matchedText = candidates.first(where: {
            $0.localizedCaseInsensitiveContains(query)
        }) else {
            return halakhah.searchPreviewText
        }

        return snippet(from: matchedText, around: query)
    }

    private func snippet(from text: String, around query: String) -> String {
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return text
        }

        let prefixStart = text.index(range.lowerBound, offsetBy: -70, limitedBy: text.startIndex) ?? text.startIndex
        let suffixEnd = text.index(range.upperBound, offsetBy: 120, limitedBy: text.endIndex) ?? text.endIndex
        var result = String(text[prefixStart..<suffixEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if prefixStart > text.startIndex {
            result = "..." + result
        }
        if suffixEnd < text.endIndex {
            result += "..."
        }

        return result
    }
}
