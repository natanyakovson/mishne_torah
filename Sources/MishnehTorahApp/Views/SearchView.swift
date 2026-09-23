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
    @State private var searchIndex: [SearchIndexEntry] = []
    @State private var halakhotByID: [UUID: MTHalakhah] = [:]

    var body: some View {
        NavigationStack {
            List(results) { halakhah in
                NavigationLink {
                    if let chapter = halakhah.chapter {
                        ReaderView(chapter: chapter, targetHalakhahContentID: halakhah.contentID)
                    } else {
                        ContentUnavailableView("Глава не найдена", systemImage: "doc.text")
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(halakhah.reference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SefariaStyle.green)
                        Text(highlightedPreview(for: halakhah))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
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
                scheduleSearch(debounce: false)
            }
            .task {
                await prepareSearchIndex()
            }
        }
        .id(navigationResetID)
        .onReceive(NotificationCenter.default.publisher(for: .returnToLibraryRoot)) { _ in
            navigationResetID = UUID()
        }
    }

    private func scheduleSearch(debounce: Bool = true) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        let index = searchIndex
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }
            let ids = await Self.matchingIDs(in: index, query: trimmed)
            guard !Task.isCancelled,
                  trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            results = ids.compactMap { halakhotByID[$0] }
            isSearching = false
        }
    }

    private func prepareSearchIndex() async {
        guard searchIndex.isEmpty else { return }
        do {
            let allHalakhot = try modelContext.fetch(FetchDescriptor<MTHalakhah>())
            halakhotByID = Dictionary(uniqueKeysWithValues: allHalakhot.map { ($0.id, $0) })
            let sources = allHalakhot.map { SearchIndexSource(id: $0.id, text: $0.searchableText) }
            searchIndex = await Task.detached(priority: .userInitiated) {
                sources.map { SearchIndexEntry(id: $0.id, normalizedText: TextSearchNormalizer.normalized($0.text)) }
            }.value
            if query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 {
                scheduleSearch(debounce: false)
            }
        } catch {
            searchIndex = []
        }
    }

    private nonisolated static func matchingIDs(in index: [SearchIndexEntry], query: String) async -> [UUID] {
        let worker = Task.detached(priority: .userInitiated) {
            let needle = TextSearchNormalizer.normalized(query).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty else { return [UUID]() }
            var matches: [UUID] = []
            for (offset, entry) in index.enumerated() {
                if offset.isMultiple(of: 256) { try Task.checkCancellation() }
                if entry.normalizedText.contains(needle) {
                    matches.append(entry.id)
                    if matches.count == 120 { break }
                }
            }
            return matches
        }
        return (try? await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }) ?? []
    }

    private func highlightedPreview(for halakhah: MTHalakhah) -> AttributedString {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = searchPreview(for: halakhah, query: trimmed)
        var attributed = AttributedString(preview)

        guard trimmed.count >= 2 else {
            return attributed
        }

        for range in TextSearchNormalizer.ranges(in: preview, matching: trimmed) {
            if let attributedRange = Range(range, in: attributed) {
                attributed[attributedRange].backgroundColor = HighlightColor.yellow.color.opacity(0.45)
                attributed[attributedRange].foregroundColor = .red
            }
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

        guard let matchedText = candidates.first(where: { TextSearchNormalizer.contains($0, query: query) }) else {
            return halakhah.searchPreviewText
        }

        return snippet(from: matchedText, around: query)
    }

    private func snippet(from text: String, around query: String) -> String {
        guard let range = TextSearchNormalizer.ranges(in: text, matching: query).first else {
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

private struct SearchIndexSource: Sendable {
    let id: UUID
    let text: String
}

private struct SearchIndexEntry: Sendable {
    let id: UUID
    let normalizedText: String
}
