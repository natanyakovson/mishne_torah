import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MTBook.order) private var books: [MTBook]
    @Query private var settings: [MTReaderSettings]
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
                LazyVStack(alignment: .leading, spacing: 16) {
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
                .padding(.vertical, 12)
                .frame(maxWidth: 940)
                .frame(maxWidth: .infinity)
            }
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HomeMenuControl(settings: activeSettings)
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
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(books) { book in
                    NavigationLink {
                        SectionListView(book: book)
                    } label: {
                        HomeBookCoverView(book: book)
                    }
                    .buttonStyle(BookCoverButtonStyle())
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

struct HomeBookCoverView: View {
    let book: MTBook
    var isMini = false

    private var coverColor: Color {
        let colors: [Color] = [
            Color(red: 0.34, green: 0.12, blue: 0.14),
            Color(red: 0.16, green: 0.27, blue: 0.22),
            Color(red: 0.15, green: 0.20, blue: 0.29),
            Color(red: 0.28, green: 0.20, blue: 0.16),
            Color(red: 0.32, green: 0.20, blue: 0.15),
            Color(red: 0.20, green: 0.21, blue: 0.20),
            Color(red: 0.27, green: 0.28, blue: 0.17)
        ]
        return colors[(max(book.order, 1) - 1) % colors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("РАМБАМ")
                .font(isMini ? .system(size: 7, weight: .medium) : .caption2.weight(.medium))

            Text("МИШНЕ ТОРА")
                .font(isMini ? .system(size: 9, weight: .semibold) : .subheadline.weight(.semibold))
                .padding(.top, isMini ? 3 : 6)

            Rectangle()
                .fill(SefariaStyle.green.opacity(0.75))
                .frame(width: isMini ? 14 : 24, height: 1)
                .padding(.vertical, isMini ? 8 : 14)

            Text(book.titleRussian.uppercased())
                .font(isMini ? .system(size: 9, weight: .semibold) : .system(size: 15, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity)

            Spacer(minLength: isMini ? 5 : 10)

            Text(String(format: "%02d", book.order))
                .font(isMini ? .system(size: 8, weight: .semibold) : .caption.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.80))
        .padding(.horizontal, isMini ? 7 : 12)
        .padding(.vertical, isMini ? 10 : 18)
        .frame(width: isMini ? 68 : 134, height: isMini ? 98 : 190)
        .background(coverColor)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(SefariaStyle.green.opacity(0.5), lineWidth: 1)
                .padding(isMini ? 3 : 5)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.black.opacity(0.13))
                .frame(width: isMini ? 3 : 5)
                .padding(.vertical, 2)
        }
        .shadow(color: .black.opacity(0.14), radius: isMini ? 3 : 5, x: 1, y: 3)
        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct BookCoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct HomeHeaderView: View {
    var body: some View {
        VStack(spacing: 5) {
            Text("רבי משה בן מימון")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .rightToLeft)

            VStack(spacing: 0) {
                Text("РАМБАМ")
                Text("МИШНЕ ТОРА")
            }
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)

            NavigationLink {
                ProjectInfoView()
            } label: {
                HStack(spacing: 6) {
                    Text("О проекте")
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

struct ProjectInfoView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let paragraphs = [
        "Учите книгу РАМБАМа и приближайте приход Мошиаха!",
        "Алтер Ребе в «Законах изучения Торы» пишет, что хорошо бы каждому пройти всю Устную Тору, хотя бы раз в жизни. Есть, конечно, длинный путь — пройти все книги Талмуда, но он доступен совсем немногим.",
        "«Мишнэ Тора» помогает осуществить этот проект почти каждому еврею. Этот труд охватывает все разделы Устной Торы — детали исполнения той или иной заповеди, постановления мудрецов, даже советы, как исправить свой характер. РАМБАМ не входит в пространные рассуждения. На красивом, ясном и очень четком языке он объясняет, как исполнить приказ Творца. Так или иначе, сейчас изучение книги РАМБАМа вошло в еврейский обиход во всех концах света.",
        "Постановление Ребе Короля Мошиаха изучать труды РАМБАМа каждый день вышло на фарбренгене в честь последнего дня Песаха в 5744 (1984) году. Ребе дал указание начать изучение всех 1006 глав (интересно, что число 1006 соответствует по гиматрии названию этого труда «Мишнэ Тора»), 27 Нисана, чтобы приурочить окончание годового цикла ко дню рождения РАМБАМа 14 Нисана 5745 года. Но Ребе ждал сюрприз… Хасиды немножко изменили порядок и приурочили окончание не к 14 Нисана, а к 11 Нисана, преподнеся Ребе подарок к дню рождения. 83 раздела были закончены в 83-й день рождения самого великого лидера всего еврейского народа.",
        "С тех пор этот обычай распространился среди евреев всего мира. Одной из целей этого постановления является укрепление единства евреев, когда «единый народ» изучает «единую Тору» и соединяется с «единым Б-гом».",
        "Во всем мире евреи изучают книгу РАМБАМа. Есть три программы (маршрута): три главы в день (заканчивают за год), по одной главе в день (заканчивают за 3 года) или «Книгу заповедей» (заканчивают за год). И как только заканчивается предыдущий цикл, начинается следующий.",
        "От Моше до Моше не было как Моше. От великого Моше-рабейну и до великого Моше бен Маймона (РАМБАМ), не было никого подобного. Мы по сегодняшний день чествуем РАМБАМа и сегодня много людей отправятся на его могилу в Тверии, отдать долг великому из великих. Учите книгу РАМБАМа и этим приближайте приход Мошиаха!"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("О проекте")
                    .font(.largeTitle.weight(.bold))
                Text("Почему изучают Мишне Тора каждый день")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(SefariaStyle.green)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(paragraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .background(SefariaStyle.panelBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle("О проекте")
        .homeNavigationButton()
    }
}

private struct HomeMenuControl: View {
    let settings: MTReaderSettings
    @State private var isShowingMenu = false

    var body: some View {
        HStack(spacing: 12) {
            Text("בס״ד")
                .font(.system(size: 13))
                .foregroundStyle(SefariaStyle.green)
                .fixedSize()
                .allowsHitTesting(false)
            Button {
                isShowingMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .help("Меню")
            .accessibilityLabel("Меню")
        }
        .popover(isPresented: $isShowingMenu, arrowEdge: .top) {
            AppMenuView(settings: settings, isPresented: $isShowingMenu)
                .frame(width: 300)
                .fixedSize(horizontal: false, vertical: true)
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct AppMenuView: View {
    @Environment(\.modelContext) private var modelContext
    let settings: MTReaderSettings
    @Binding var isPresented: Bool

    private var selectedCycle: Binding<ReadingCycle> {
        Binding(
            get: { ReadingCycle(rawValue: settings.readingCycleRawValue ?? "") ?? .none },
            set: { cycle in
                settings.readingCycleRawValue = cycle.rawValue
                try? modelContext.save()
                isPresented = false
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Меню")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть меню")
            }
            Text("Навигация и цикл чтения")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Divider()
            Text("Выбранный цикл")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(ReadingCycle.selectableCases) { cycle in
                Button {
                    selectedCycle.wrappedValue = cycle
                } label: {
                    HStack {
                        Text(cycle.title)
                        Spacer()
                        Image(systemName: "checkmark")
                            .opacity(selectedCycle.wrappedValue == cycle ? 1 : 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedCycle.wrappedValue == cycle ? .isSelected : [])
            }
            Divider()
            Text("После выбора цикл появится на главной странице в карточке чтения на сегодня.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
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

            Picker("Рамбам", selection: Binding(
                get: { ReadingCycle(rawValue: settings.readingCycleRawValue ?? "") ?? .none },
                set: { cycle in
                    settings.readingCycleRawValue = cycle.rawValue
                    try? modelContext.save()
                }
            )) {
                ForEach(ReadingCycle.selectableCases) { cycle in
                    Text(cycle.title).tag(cycle)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

}

struct DailyRambamCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let reading: DailyRambamReading
    let date: Date

    private var dateText: String {
        AppDateFormatter.combinedDateString(for: date)
    }

    private var bookGroups: [[[MTChapter]]] {
        var groups: [[[MTChapter]]] = []
        for chapter in reading.chapters {
            guard let section = chapter.section, let book = section.book else { continue }
            if let bookIndex = groups.firstIndex(where: { $0.first?.first?.section?.book?.id == book.id }) {
                if let sectionIndex = groups[bookIndex].firstIndex(where: { $0.first?.section?.id == section.id }) {
                    groups[bookIndex][sectionIndex].append(chapter)
                } else {
                    groups[bookIndex].append([chapter])
                }
            } else {
                groups.append([[chapter]])
            }
        }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "calendar")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SefariaStyle.green)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("СЕГОДНЯ")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(SefariaStyle.green)
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(bookGroups.indices, id: \.self) { bookIndex in
                VStack(alignment: .leading, spacing: 6) {
                    Text(bookGroups[bookIndex].first?.first?.section?.book?.titleRussian ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(bookGroups[bookIndex].indices, id: \.self) { sectionIndex in
                        let chapters = bookGroups[bookIndex][sectionIndex]
                        if let chapter = chapters.first {
                            NavigationLink {
                                ReaderView(chapter: chapter)
                            } label: {
                                DailyRambamChapterRow(chapter: chapter, chapters: chapters)
                            }
                            .buttonStyle(DailyRambamLinkStyle())
                        }
                    }
                }
            }

            Divider()

            HStack {
                Text(reading.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let firstChapter = reading.chapters.first {
                    NavigationLink {
                        ReaderView(chapter: firstChapter)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Читать")
                                .font(.footnote.weight(.semibold))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(SefariaStyle.green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(SefariaStyle.line.opacity(colorScheme == .dark ? 0.22 : 0.32), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

struct DailyRambamChapterRow: View {
    let chapter: MTChapter
    let chapters: [MTChapter]

    private var chapterNumbers: String {
        let numbers = chapters.map(\.number).sorted()
        guard let first = numbers.first, let last = numbers.last else { return "" }
        if numbers.count == 1 { return "\(first)" }
        let consecutive = zip(numbers, numbers.dropFirst()).allSatisfy { $1 == $0 + 1 }
        return consecutive ? "\(first)–\(last)" : numbers.map { String($0) }.joined(separator: ", ")
    }

    private var chapterLabel: String {
        "\(chapters.count == 1 ? "Глава" : "Главы") \(chapterNumbers)"
    }

    var body: some View {
        if let section = chapter.section {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                (Text(section.titleRussian).font(.system(size: 17, weight: .semibold)).foregroundColor(.primary)
                 + Text(" · гл. \(chapterNumbers)").font(.system(size: 16, weight: .regular)).foregroundColor(.secondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: 17))
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(section.titleRussian), \(chapterLabel)")
            .accessibilityHint("Открыть чтение на сегодня")
        }
    }
}

private struct DailyRambamLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SectionListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedSectionID: PersistentIdentifier?
    let book: MTBook

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BookHeader(book: book)
                    .padding(.horizontal, 18)

                ForEach(book.sortedSections) { section in
                    SectionAccordionRow(
                        section: section,
                        isExpanded: expandedSectionID == section.persistentModelID
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            expandedSectionID = expandedSectionID == section.persistentModelID ? nil : section.persistentModelID
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(SefariaStyle.panelBackground(for: colorScheme))

                    Divider()
                        .overlay(SefariaStyle.line.opacity(0.45))
                        .padding(.horizontal, 18)
                }
            }
        }
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle(book.titleRussian)
        .homeNavigationButton()
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
                                    .foregroundStyle(SefariaStyle.green)
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
        .homeNavigationButton()
    }
}

struct BookHeader: View {
    let book: MTBook

    var body: some View {
        return VStack(alignment: .leading, spacing: 10) {
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

private struct SectionAccordionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let section: MTSection
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleExpansion()
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(section.titleRussian)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(section.sortedChapters.count) глав")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SefariaStyle.green)
                        .frame(width: 28, height: 44)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(section.sortedChapters.isEmpty)

            if isExpanded {
                ChapterPathView(chapters: section.sortedChapters)
                .padding(.bottom, 16)
                .transition(.opacity)
            }
        }
    }
}

private struct ChapterPathView: View {
    @State private var selectedChapter: MTChapter?
    let chapters: [MTChapter]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            rows(columnCount: 4)
            rows(columnCount: 3)
            rows(columnCount: 2)
        }
        .environment(\.layoutDirection, .leftToRight)
        .navigationDestination(isPresented: Binding(
            get: { selectedChapter != nil },
            set: { if !$0 { selectedChapter = nil } }
        )) {
            if let selectedChapter {
                ReaderView(chapter: selectedChapter)
            }
        }
    }

    private func rows(columnCount: Int) -> some View {
        let starts = Array(stride(from: 0, to: chapters.count, by: columnCount))

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(starts, id: \.self) { start in
                ChapterPathRow(
                    chapters: Array(chapters[start..<min(start + columnCount, chapters.count)]),
                    selectedChapter: $selectedChapter
                )
            }
        }
    }
}

private struct ChapterPathRow: View {
    let chapters: [MTChapter]
    @Binding var selectedChapter: MTChapter?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(chapters.enumerated()), id: \.offset) { index, chapter in
                Button {
                    selectedChapter = chapter
                } label: {
                    Text("Глава \(chapter.number)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 74, height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(SefariaStyle.green.opacity(0.7), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(DailyRambamLinkStyle())

                if index < chapters.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SefariaStyle.green.opacity(0.65))
                        .accessibilityHidden(true)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct BookRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let book: MTBook

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("\(book.order)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(SefariaStyle.green, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(book.titleRussian)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.titleHebrew)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
                .frame(width: 28, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SefariaStyle.line.opacity(colorScheme == .dark ? 0.18 : 0.26), lineWidth: 0.75)
        }
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
