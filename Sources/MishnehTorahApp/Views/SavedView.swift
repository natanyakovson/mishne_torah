import SwiftData
import SwiftUI

struct SavedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MTBookmark.createdAt, order: .reverse) private var bookmarks: [MTBookmark]
    @Query(sort: \MTReadingHistory.lastReadAt, order: .reverse) private var history: [MTReadingHistory]
    @State private var mode: SavedMode = .bookmarks
    @State private var isConfirmingClearBookmarks = false
    @State private var navigationResetID = UUID()

    var body: some View {
        NavigationStack {
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
                    if bookmarks.isEmpty {
                        ContentUnavailableView("Закладок пока нет", systemImage: "bookmark")
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(bookmarks) { bookmark in
                            if let halakhah = bookmark.halakhah {
                                SavedLink(halakhah: halakhah, date: bookmark.createdAt)
                            }
                        }
                        .onDelete(perform: deleteBookmarks)
                    }
                case .history:
                    ForEach(history.prefix(100)) { item in
                        if let halakhah = item.halakhah {
                            SavedLink(halakhah: halakhah, date: item.lastReadAt)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Сохранённое")
            .homeNavigationButton()
            .toolbar {
                if mode == .bookmarks, !bookmarks.isEmpty {
                    Button(role: .destructive) {
                        isConfirmingClearBookmarks = true
                    } label: {
                        Label("Очистить", systemImage: "trash")
                    }
                    .help("Очистить все закладки")
                }
            }
            .confirmationDialog("Удалить все закладки?", isPresented: $isConfirmingClearBookmarks, titleVisibility: .visible) {
                Button("Удалить все закладки", role: .destructive) {
                    clearAllBookmarks()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
        .id(navigationResetID)
        .onReceive(NotificationCenter.default.publisher(for: .returnToLibraryRoot)) { _ in
            navigationResetID = UUID()
        }
    }

    private func deleteBookmarks(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bookmarks[index])
        }
        try? modelContext.save()
    }

    private func clearAllBookmarks() {
        for bookmark in bookmarks {
            modelContext.delete(bookmark)
        }
        try? modelContext.save()
    }
}

struct SavedLink: View {
    let halakhah: MTHalakhah
    let date: Date

    var body: some View {
        NavigationLink {
            if let chapter = halakhah.chapter {
                ReaderView(chapter: chapter)
            } else {
                ContentUnavailableView("Глава не найдена", systemImage: "bookmark")
            }
        } label: {
            SavedRow(halakhah: halakhah, date: date)
        }
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
