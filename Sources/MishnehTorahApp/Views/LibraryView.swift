import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MTBook.order) private var books: [MTBook]
    @Query private var settings: [MTReaderSettings]
    @State private var isShowingMenu = false
    @State private var currentDate = Date()
    @State private var navigationResetID = UUID()

    private var activeSettings: MTReaderSettings {
        if let settings = settings.first {
            return settings
        }
        let created = MTReaderSettings()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }

    private var activeCycle: ReadingCycle {
        ReadingCycle(rawValue: activeSettings.readingCycleRawValue ?? "") ?? .none
    }

    private var dailyReading: DailyRambamReading? {
        ReadingCycleSchedule.reading(for: activeCycle, books: books, date: currentDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    HomeHeaderView()

                    if let dailyReading {
                        DailyRambamCard(reading: dailyReading, date: currentDate)
                    } else {
                        ReadingCyclePickerCard(settings: activeSettings, date: currentDate)
                    }

                    SefariaSectionTitle("Все книги")

                    BookListView(books: books)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(maxWidth: 940)
                .frame(maxWidth: .infinity)
            }
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingMenu = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .help("Меню")
                    .accessibilityLabel("Меню")
                    .popover(isPresented: $isShowingMenu, arrowEdge: .top) {
                        AppMenuView(settings: activeSettings)
                            .presentationCompactAdaptation(.popover)
                            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                    }
                }
            }
            .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
                currentDate = date
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    currentDate = Date()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .returnToLibraryRoot)) { _ in
                currentDate = Date()
                navigationResetID = UUID()
            }
        }
        .id(navigationResetID)
    }
}

struct BookListView: View {
    let books: [MTBook]

    var body: some View {
        LazyVStack(spacing: 18) {
            ForEach(books) { book in
                NavigationLink {
                    SectionListView(book: book)
                } label: {
                    BookRow(book: book)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HomeHeaderView: View {
    var body: some View {
        VStack(spacing: 7) {
            Text("רבי משה בן מימון")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .rightToLeft)

            Link("Кодекс Маймонида - Мишне Тора", destination: URL(string: "https://m770.org/rambam/")!)
                .font(.title3.weight(.medium))
                .foregroundStyle(SefariaStyle.linkBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 18)
    }
}

struct AppMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let settings: MTReaderSettings

    private var selectedCycle: Binding<ReadingCycle> {
        Binding(
            get: { ReadingCycle(rawValue: settings.readingCycleRawValue ?? "") ?? .none },
            set: { cycle in
                settings.readingCycleRawValue = cycle.rawValue
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Меню")
                        .font(.title2.weight(.semibold))
                    Text("Навигация и цикл чтения")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Выбранный цикл")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Цикл чтения", selection: selectedCycle) {
                        ForEach(ReadingCycle.selectableCases) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }
                    .pickerStyle(.inline)
                }
                .padding(12)
                .background(SefariaStyle.panelBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("После выбора цикл появится на главной странице в карточке чтения на сегодня.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
            .background(SefariaStyle.background(for: colorScheme))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Закрыть меню")
                }
            }
        }
    }
}

struct ReadingCyclePickerCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    let settings: MTReaderSettings
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Выберите цикл чтения Рамбама")
                    .font(.title3.weight(.semibold))
                Text(AppDateFormatter.combinedDateString(for: date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                cycleButton(.oneChapter)
                cycleButton(.threeChapters)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func cycleButton(_ cycle: ReadingCycle) -> some View {
        Button {
            settings.readingCycleRawValue = cycle.rawValue
            try? modelContext.save()
        } label: {
            VStack(spacing: 4) {
                Text(cycle.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(cycle.shortTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SefariaStyle.green.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DailyRambamCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let reading: DailyRambamReading
    let date: Date

    private var dateText: String {
        AppDateFormatter.combinedDateString(for: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Чтение на сегодня")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(reading.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SefariaStyle.green)
            }

            ForEach(reading.chapters) { chapter in
                NavigationLink {
                    ReaderView(chapter: chapter)
                } label: {
                    DailyRambamChapterRow(chapter: chapter)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DailyRambamChapterRow: View {
    let chapter: MTChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let section = chapter.section, let book = section.book {
                Text(book.titleRussian)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(section.titleRussian)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Text("Глава \(chapter.number)")
                .font(.caption)
                .foregroundStyle(SefariaStyle.green)
        }
        .padding(.vertical, 4)
    }
}

struct SectionListView: View {
    @Environment(\.colorScheme) private var colorScheme
    let book: MTBook

    var body: some View {
        List {
            BookHeader(book: book)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            Section {
                ForEach(book.sortedSections) { section in
                    NavigationLink {
                        ChapterGridView(section: section)
                    } label: {
                        SectionRow(section: section)
                    }
                    .disabled(section.sortedChapters.isEmpty)
                    .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))
                    .listRowBackground(SefariaStyle.panelBackground(for: colorScheme))
                    .listRowSeparatorTint(SefariaStyle.line.opacity(0.45))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle(book.titleRussian)
    }
}

struct ChapterGridView: View {
    @Environment(\.colorScheme) private var colorScheme
    let section: MTSection

    private let columns = [
        GridItem(.adaptive(minimum: 88, maximum: 120), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    if let book = section.book {
                        Text(book.titleRussian)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SefariaStyle.green)
                        Text(book.titleHebrew)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SefariaStyle.deepGreen)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                    }
                    Text(section.titleRussian)
                        .font(.title2.weight(.semibold))
                    Text(section.titleHebrew)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(section.sortedChapters) { chapter in
                        NavigationLink {
                            ReaderView(chapter: chapter)
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(chapter.number)")
                                    .font(.title3.weight(.semibold))
                                Text("Глава")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("פרק \(chapter.number)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .environment(\.layoutDirection, .rightToLeft)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 82)
                            .background(SefariaStyle.panelBackground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(SefariaStyle.line.opacity(0.55), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle("Главы")
    }
}

struct BookHeader: View {
    let book: MTBook

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(book.titleRussian)
                .font(.largeTitle.weight(.bold))
            Text(book.titleHebrew)
                .font(.title.weight(.semibold))
                .foregroundStyle(SefariaStyle.deepGreen)
                .environment(\.layoutDirection, .rightToLeft)
            Text("\(book.sortedSections.count) разделов")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct BookRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let book: MTBook

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Text("\(book.order)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(SefariaStyle.green, in: Circle())

            VStack(alignment: .leading, spacing: 10) {
                Text(book.titleRussian)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.titleHebrew)
                    .font(.title3)
                    .foregroundStyle(SefariaStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Открыть")
                .font(.headline.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
                .overlay {
                    Capsule()
                        .stroke(SefariaStyle.green.opacity(0.55), lineWidth: 1)
                }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 26)
        .background(SefariaStyle.panelBackground(for: colorScheme).opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: .infinity)
    }
}

struct BookCoverView: View {
    let book: MTBook

    private var coverColor: Color {
        let colors = [
            Color(red: 0.55, green: 0.05, blue: 0.04),
            Color(red: 0.50, green: 0.23, blue: 0.02),
            Color(red: 0.09, green: 0.18, blue: 0.32),
            Color(red: 0.13, green: 0.30, blue: 0.23),
            Color(red: 0.35, green: 0.16, blue: 0.30),
            Color(red: 0.42, green: 0.29, blue: 0.12)
        ]
        return colors[(book.order - 1) % colors.count]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [coverColor.opacity(0.95), coverColor.opacity(0.65), .black.opacity(0.45)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 4)

            RoundedRectangle(cornerRadius: 3)
                .stroke(.white.opacity(0.42), lineWidth: 1)
                .padding(7)

            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(width: 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)

            VStack(spacing: 8) {
                Text("РАМБАМ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                Text("Мишне Тора")
                    .font(.system(size: 21, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                Spacer(minLength: 2)
                Text(shortBookTitle)
                    .font(.system(size: 18, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.92))
                    .minimumScaleFactor(0.55)
                    .lineLimit(3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 22)
        }
        .accessibilityHidden(true)
    }

    private var shortBookTitle: String {
        book.titleRussian
            .replacingOccurrences(of: "Книга", with: "")
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SectionRow: View {
    let section: MTSection

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.title3)
                .foregroundStyle(SefariaStyle.green)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 5) {
                Text(section.titleRussian)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.primary)
                Text(section.titleHebrew)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(SefariaStyle.deepGreen.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }

            Text("\(section.sortedChapters.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 24)
        }
        .padding(.vertical, 12)
    }
}
