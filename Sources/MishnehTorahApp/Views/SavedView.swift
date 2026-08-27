import SwiftData
import SwiftUI

struct SavedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MTBookmark.createdAt, order: .reverse) private var bookmarks: [MTBookmark]
    @Query(sort: \MTReadingHistory.lastReadAt, order: .reverse) private var history: [MTReadingHistory]
    @State private var mode: SavedMode = .bookmarks
    @State private var selectedChapter: MTChapter?

    var body: some View {
        NavigationSplitView {
            List {
                SefariaSectionTitle("Личный кабинет", subtitle: "Закладки и история чтения")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                Picker("Режим", selection: $mode) {
                    ForEach(SavedMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                switch mode {
                case .bookmarks:
                    ForEach(bookmarks) { bookmark in
                        if let halakhah = bookmark.halakhah {
                            SavedRow(halakhah: halakhah, date: bookmark.createdAt)
                                .onTapGesture {
                                    selectedChapter = halakhah.chapter
                                }
                        }
                    }
                    .onDelete(perform: deleteBookmarks)
                case .history:
                    ForEach(history.prefix(100)) { item in
                        if let halakhah = item.halakhah {
                            SavedRow(halakhah: halakhah, date: item.lastReadAt)
                                .onTapGesture {
                                    selectedChapter = halakhah.chapter
                                }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Сохранённое")
        } detail: {
            if let selectedChapter {
                ReaderView(chapter: selectedChapter)
            } else {
                ContentUnavailableView("Выберите запись", systemImage: "bookmark")
            }
        }
    }

    private func deleteBookmarks(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
        try? modelContext.save()
    }
}

struct SavedRow: View {
    let halakhah: MTHalakhah
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(halakhah.reference)
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(SefariaStyle.green)
            Text(date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(halakhah.searchPreviewText)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

enum SavedMode: String, CaseIterable, Identifiable {
    case bookmarks
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmarks: "Закладки"
        case .history: "История"
        }
    }
}
