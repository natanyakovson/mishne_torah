import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \MTBook.order) private var books: [MTBook]
    @State private var selectedBookID: UUID?
    @State private var selectedChapterID: UUID?

    var selectedBook: MTBook? {
        books.first { $0.id == selectedBookID } ?? books.first
    }

    var selectedChapter: MTChapter? {
        guard let selectedBook else { return nil }
        return selectedBook.sortedSections
            .flatMap(\.sortedChapters)
            .first { $0.id == selectedChapterID }
            ?? selectedBook.sortedSections.first?.sortedChapters.first
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedBookID) {
                SefariaSectionTitle("Мишне Тора", subtitle: "14 книг Рамбама")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                ForEach(books) { book in
                    BookRow(book: book)
                    .tag(book.id)
                }
            }
            .scrollContentBackground(.hidden)
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Тексты")
            .onAppear {
                selectedBookID = selectedBookID ?? books.first?.id
            }
        } content: {
            if let selectedBook {
                ChapterListView(book: selectedBook, selectedChapterID: $selectedChapterID)
            } else {
                ContentUnavailableView("Нет данных", systemImage: "tray")
            }
        } detail: {
            if let selectedChapter {
                ReaderView(chapter: selectedChapter)
            } else {
                ContentUnavailableView("Выберите главу", systemImage: "book")
            }
        }
    }
}

struct ChapterListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let book: MTBook
    @Binding var selectedChapterID: UUID?

    var body: some View {
        List(selection: $selectedChapterID) {
            VStack(alignment: .leading, spacing: 10) {
                Text(book.titleHebrew)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SefariaStyle.deepGreen)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(book.titleRussian)
                    .font(.title3.weight(.regular))
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            ForEach(book.sortedSections) { section in
                Section {
                    ForEach(section.sortedChapters) { chapter in
                        HStack {
                            Text("Глава \(chapter.number)")
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 5)
                            .tag(chapter.id)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(section.titleHebrew)
                            .font(.headline)
                            .foregroundStyle(SefariaStyle.green)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text(section.titleRussian)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle(book.titleRussian)
        .onAppear {
            selectedChapterID = selectedChapterID ?? book.sortedSections.first?.sortedChapters.first?.id
        }
        .onChange(of: book.id) {
            selectedChapterID = book.sortedSections.first?.sortedChapters.first?.id
        }
    }
}

struct BookRow: View {
    let book: MTBook

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(book.order)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(SefariaStyle.green, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(book.titleRussian)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(book.titleHebrew)
                    .font(.subheadline)
                    .foregroundStyle(SefariaStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
        }
        .padding(.vertical, 8)
    }
}
