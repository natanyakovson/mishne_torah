import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ReaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [MTReaderSettings]
    @Query private var bookmarks: [MTBookmark]
    @Query(sort: \MTTextHighlight.createdAt, order: .reverse) private var highlights: [MTTextHighlight]
    @State private var didRecordReading = false
    @State private var activeSheet: ReaderSheet?
    @State private var isReaderMenuExpanded = false
    let chapter: MTChapter

    init(chapter: MTChapter) {
        self.chapter = chapter
    }

    private var textSize: Double {
        settings.first?.textSize ?? 24
    }

    private var readerLanguage: ReaderLanguage {
        ReaderLanguage(rawValue: settings.first?.readerLanguageRawValue ?? "") ?? .russian
    }

    private var readerFont: ReaderFont {
        ReaderFont(rawValue: settings.first?.readerFontRawValue ?? "") ?? .times
    }

    private var customFontName: String? {
        settings.first?.customFontName
    }

    private var chapterNavigation: (previous: MTChapter?, next: MTChapter?) {
        guard let section = chapter.section,
              let book = section.book else {
            return (nil, nil)
        }
        let chapters = book.sortedSections.flatMap(\.sortedChapters)
        guard let index = chapters.firstIndex(where: { $0.id == chapter.id }) else {
            return (nil, nil)
        }
        let previous = index > 0 ? chapters[index - 1] : nil
        let next = index + 1 < chapters.count ? chapters[index + 1] : nil
        return (previous, next)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                ReaderHeader(
                    chapter: chapter,
                    previousChapter: chapterNavigation.previous,
                    nextChapter: chapterNavigation.next
                )

                ForEach(chapter.sortedHalakhot) { halakhah in
                    HalakhahCard(
                        halakhah: halakhah,
                        textSize: textSize,
                        readerFont: readerFont,
                        customFontName: customFontName,
                        readerLanguage: readerLanguage,
                        isBookmarked: isBookmarked(halakhah),
                        russianHighlights: highlights(for: halakhah, language: .russian),
                        hebrewHighlights: highlights(for: halakhah, language: .hebrew)
                    ) {
                        toggleBookmark(for: halakhah)
                    } addHighlight: { range, selectedText, language, color in
                        addHighlight(color, selectedText: selectedText, range: range, for: halakhah, language: language)
                    } deleteHighlight: { range, language in
                        deleteHighlights(in: range, for: halakhah, language: language)
                    }
                        .id(halakhah.id)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .padding(.bottom, 96)
            .frame(maxWidth: 1080)
            .frame(maxWidth: .infinity)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                if isReaderMenuExpanded {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                        isReaderMenuExpanded = false
                    }
                }
            }
        )
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle("Глава \(chapter.number)")
        .homeNavigationButton()
        .safeAreaInset(edge: .bottom) {
            ReaderBottomBar(
                chapterTitle: "Глава \(chapter.number)",
                openContents: { activeSheet = .contents },
                openSearch: { activeSheet = .search },
                openSettings: { activeSheet = .settings },
                isExpanded: $isReaderMenuExpanded
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .contents:
                ReaderContentsSheet(
                    chapter: chapter,
                    bookmarks: bookmarks,
                    highlights: highlights
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .search:
                SearchView()
                    .presentationDetents([.large])
            case .settings:
                SettingsView()
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            FontInstallService.registerStoredFont(fileName: settings.first?.customFontFileName)
            guard !didRecordReading, let firstHalakhah = chapter.sortedHalakhot.first else {
                return
            }
            didRecordReading = true
            recordReading(firstHalakhah)
        }
    }

    private func recordReading(_ halakhah: MTHalakhah) {
        let history = MTReadingHistory(halakhah: halakhah)
        modelContext.insert(history)
        try? modelContext.save()
    }

    private func isBookmarked(_ halakhah: MTHalakhah) -> Bool {
        bookmarks.contains { $0.halakhah?.id == halakhah.id }
    }

    private func toggleBookmark(for halakhah: MTHalakhah) {
        let existingBookmarks = bookmarks.filter { $0.halakhah?.id == halakhah.id }
        if existingBookmarks.isEmpty {
            modelContext.insert(MTBookmark(halakhah: halakhah))
        } else {
            for bookmark in existingBookmarks {
                modelContext.delete(bookmark)
            }
        }
        try? modelContext.save()
    }

    private func highlights(for halakhah: MTHalakhah, language: ReaderLanguage) -> [MTTextHighlight] {
        highlights.filter { highlight in
            highlight.halakhah?.id == halakhah.id &&
            highlight.languageRawValue == language.rawValue &&
            highlight.length > 0
        }
    }

    private func addHighlight(_ color: HighlightColor, selectedText: String, range: NSRange, for halakhah: MTHalakhah, language: ReaderLanguage) {
        let overlappingHighlights = highlights.filter { highlight in
            highlight.halakhah?.id == halakhah.id &&
            highlight.languageRawValue == language.rawValue &&
            highlight.range.intersects(range)
        }
        for highlight in overlappingHighlights {
            modelContext.delete(highlight)
        }

        modelContext.insert(
            MTTextHighlight(
                colorRawValue: color.rawValue,
                selectedText: selectedText,
                startLocation: range.location,
                length: range.length,
                languageRawValue: language.rawValue,
                halakhah: halakhah
            )
        )
        try? modelContext.save()
    }

    private func deleteHighlights(in range: NSRange, for halakhah: MTHalakhah, language: ReaderLanguage) {
        let overlappingHighlights = highlights.filter { highlight in
            highlight.halakhah?.id == halakhah.id &&
            highlight.languageRawValue == language.rawValue &&
            highlight.range.intersects(range)
        }
        for highlight in overlappingHighlights {
            modelContext.delete(highlight)
        }
        try? modelContext.save()
    }

}

private extension MTTextHighlight {
    var range: NSRange {
        NSRange(location: startLocation, length: length)
    }
}

private extension NSRange {
    func intersects(_ other: NSRange) -> Bool {
        NSIntersectionRange(self, other).length > 0
    }
}

enum ReaderSheet: String, Identifiable {
    case contents
    case search
    case settings

    var id: String { rawValue }
}

struct ReaderBottomBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let chapterTitle: String
    let openContents: () -> Void
    let openSearch: () -> Void
    let openSettings: () -> Void
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isExpanded {
                VStack(alignment: .trailing, spacing: 4) {
                    expandedButton(title: "Оглавление", subtitle: chapterTitle, systemImage: "line.3.horizontal") {
                        isExpanded = false
                        openContents()
                    }

                    expandedButton(title: "Искать в книге", subtitle: nil, systemImage: "magnifyingglass") {
                        isExpanded = false
                        openSearch()
                    }

                    expandedButton(title: "Темы и настройки", subtitle: nil, systemImage: "textformat.size") {
                        isExpanded = false
                        openSettings()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(SefariaStyle.deepGreen, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .accessibilityLabel(isExpanded ? "Закрыть меню" : "Открыть меню")
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func expandedButton(title: String, subtitle: String?, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(subtitle.map { "\(title) • \($0)" } ?? title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SefariaStyle.deepGreen)
                }
                Spacer(minLength: 12)
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(systemImage == "bookmark.fill" ? SefariaStyle.gold : .black)
                    .frame(width: 28)
            }
            .frame(width: 274)
            .frame(height: 40)
            .padding(.horizontal, 13)
            .background(.regularMaterial, in: Capsule())
            .background(SefariaStyle.panelBackground(for: colorScheme).opacity(0.78), in: Capsule())
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(ReaderMenuButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct ReaderMenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ReaderContentsSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let chapter: MTChapter
    let bookmarks: [MTBookmark]
    let highlights: [MTTextHighlight]
    @State private var tab: ReaderContentsTab = .chapters

    private var section: MTSection? {
        chapter.section
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let section, let book = section.book {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(book.titleRussian)
                            .font(.headline.weight(.semibold))
                        Text(section.titleRussian)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(SefariaStyle.deepGreen)
                    }
                    .buttonStyle(.plain)
                }

                Picker("Оглавление", selection: $tab) {
                    ForEach(ReaderContentsTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    switch tab {
                    case .chapters:
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(book.sortedSections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.titleRussian)
                                        .font(.headline.weight(.semibold))
                                    Text(section.titleHebrew)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .environment(\.layoutDirection, .rightToLeft)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                                        ForEach(section.sortedChapters) { item in
                                            NavigationLink {
                                                ReaderView(chapter: item)
                                            } label: {
                                                VStack(spacing: 2) {
                                                    Text("\(item.number)")
                                                        .font(.headline.weight(item.id == chapter.id ? .bold : .regular))
                                                    Text("פרק")
                                                        .font(.caption2)
                                                }
                                                    .foregroundStyle(item.id == chapter.id ? .white : SefariaStyle.green)
                                                    .frame(maxWidth: .infinity)
                                                    .frame(height: 50)
                                                    .background(item.id == chapter.id ? SefariaStyle.green : SefariaStyle.panelBackground(for: colorScheme))
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(SefariaStyle.line.opacity(0.5), lineWidth: 1)
                                                    }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.bottom, 6)
                            }
                        }
                    case .bookmarks:
                        SheetHalakhahList(
                            emptyTitle: "Закладок пока нет",
                            halakhot: bookmarks.compactMap(\.halakhah)
                        )
                    case .highlights:
                        SheetHalakhahList(
                            emptyTitle: "Выделений пока нет",
                            halakhot: highlights.compactMap(\.halakhah)
                        )
                    }
                }
            } else {
                Text("Оглавление недоступно")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .background(SefariaStyle.background(for: colorScheme))
    }
}

enum ReaderContentsTab: String, CaseIterable, Identifiable {
    case chapters
    case bookmarks
    case highlights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chapters: "Главы"
        case .bookmarks: "Закладки"
        case .highlights: "Выделенное"
        }
    }
}

struct SheetHalakhahList: View {
    let emptyTitle: String
    let halakhot: [MTHalakhah]

    var body: some View {
        if halakhot.isEmpty {
            ContentUnavailableView(emptyTitle, systemImage: "text.badge.xmark")
                .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(halakhot) { halakhah in
                    NavigationLink {
                        if let chapter = halakhah.chapter {
                            ReaderView(chapter: chapter)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(halakhah.reference)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SefariaStyle.green)
                            Text(halakhah.searchPreviewText)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ReaderHeader: View {
    let chapter: MTChapter
    let previousChapter: MTChapter?
    let nextChapter: MTChapter?

    var body: some View {
        VStack(spacing: 22) {
            if let section = chapter.section, let book = section.book {
                VStack(spacing: 14) {
                    HStack(spacing: 7) {
                        Image(systemName: "book.closed")
                            .font(.caption2.weight(.semibold))
                        Text(book.titleRussian.uppercased())
                    }
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(SefariaStyle.green)

                    Text(section.titleRussian)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 620)

                    HStack(spacing: 7) {
                        if !section.titleHebrew.isEmpty {
                            Text(section.titleHebrew)
                                .foregroundStyle(SefariaStyle.green)
                                .environment(\.layoutDirection, .rightToLeft)
                            Text("•")
                                .foregroundStyle(.tertiary)
                        }
                        Text("Глава \(chapter.number)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)

                HStack(spacing: 10) {
                    if let previousChapter {
                        NavigationLink {
                            ReaderView(chapter: previousChapter)
                        } label: {
                            Label("Предыдущая", systemImage: "chevron.left")
                        }
                    }

                    NavigationLink {
                        SectionListView(book: book)
                    } label: {
                        Label("Книга", systemImage: "list.bullet")
                    }

                    if let nextChapter {
                        NavigationLink {
                            ReaderView(chapter: nextChapter)
                        } label: {
                            Label("Следующая", systemImage: "chevron.right")
                        }
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
    }
}

struct HalakhahCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let halakhah: MTHalakhah
    let textSize: Double
    let readerFont: ReaderFont
    let customFontName: String?
    let readerLanguage: ReaderLanguage
    let isBookmarked: Bool
    let russianHighlights: [MTTextHighlight]
    let hebrewHighlights: [MTTextHighlight]
    let toggleBookmark: () -> Void
    let addHighlight: (NSRange, String, ReaderLanguage, HighlightColor) -> Void
    let deleteHighlight: (NSRange, ReaderLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if readerLanguage != .hebrew {
                SelectableHalakhahText(
                    text: halakhah.russianDisplayText,
                    prefix: "\(halakhah.number). ",
                    textSize: textSize,
                    lineSpacing: 9,
                    readerFont: readerFont,
                    customFontName: customFontName,
                    layoutDirection: .leftToRight,
                    highlights: russianHighlights,
                    reservesTopTrailingSpace: true
                ) { range, selectedText, color in
                    addHighlight(range, selectedText, .russian, color)
                } deleteHighlight: { range in
                    deleteHighlight(range, .russian)
                }
            }

            if readerLanguage == .hebrew {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(halakhah.number).")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SefariaStyle.green)
                        .fixedSize()

                    SelectableHalakhahText(
                        text: halakhah.hebrewDisplayText,
                        textSize: textSize,
                        lineSpacing: 8,
                        readerFont: readerFont,
                        customFontName: customFontName,
                        layoutDirection: .rightToLeft,
                        highlights: hebrewHighlights
                    ) { range, selectedText, color in
                        addHighlight(range, selectedText, .hebrew, color)
                    } deleteHighlight: { range in
                        deleteHighlight(range, .hebrew)
                    }
                    .layoutPriority(1)

                    bookmarkButton
                        .fixedSize()
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                }
            } else if readerLanguage == .both {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(SefariaStyle.line.opacity(0.42))
                        .frame(height: 0.75)
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(SefariaStyle.green)
                    Rectangle()
                        .fill(SefariaStyle.line.opacity(0.42))
                        .frame(height: 0.75)
                }
                .padding(.vertical, 6)

                Text("עברית")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)

                SelectableHalakhahText(
                    text: halakhah.hebrewDisplayText,
                    textSize: textSize,
                    lineSpacing: 8,
                    readerFont: readerFont,
                    customFontName: customFontName,
                    layoutDirection: .rightToLeft,
                    highlights: hebrewHighlights
                ) { range, selectedText, color in
                    addHighlight(range, selectedText, .hebrew, color)
                } deleteHighlight: { range in
                    deleteHighlight(range, .hebrew)
                }
            }

            if readerLanguage == .russian, halakhah.russianText == nil {
                Text("Русский текст для этого закона ещё не импортирован.")
                    .font(readerFont.font(size: max(textSize - 4, 16), customName: customFontName))
                    .foregroundStyle(.secondary)
            }

            if readerLanguage != .russian, halakhah.hebrewText.isEmpty {
                Text("Иврит для этого закона не найден в источнике.")
                    .font(readerFont.font(size: max(textSize - 4, 16), customName: customFontName))
                    .foregroundStyle(.secondary)
            }

            if !halakhah.notes.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(halakhah.notes.enumerated()), id: \.offset) { _, note in
                            Text(note)
                                .font(readerFont.font(size: max(textSize - 5, 15), customName: customFontName))
                                .lineSpacing(6)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Label("Примечания", systemImage: "text.bubble")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SefariaStyle.green)
                }
            }
        }
        .padding(20)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SefariaStyle.line.opacity(colorScheme == .dark ? 0.18 : 0.28), lineWidth: 0.75)
        }
        .overlay(alignment: .topTrailing) {
            if readerLanguage != .hebrew {
                bookmarkButton
                    .padding(20)
            }
        }
        .contextMenu {
            Button(isBookmarked ? "Убрать закладку" : "Добавить закладку") {
                toggleBookmark()
            }
        }
    }

    private var bookmarkButton: some View {
        Button {
            toggleBookmark()
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title3.weight(.medium))
                .foregroundStyle(isBookmarked ? SefariaStyle.gold : SefariaStyle.green)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .help(isBookmarked ? "Убрать из закладок" : "Добавить в закладки")
        .accessibilityLabel(isBookmarked ? "Убрать из закладок" : "Добавить в закладки")
    }
}

struct SelectableHalakhahText: View {
    let text: String
    var prefix = ""
    let textSize: Double
    let lineSpacing: CGFloat
    let readerFont: ReaderFont
    let customFontName: String?
    let layoutDirection: LayoutDirection
    let highlights: [MTTextHighlight]
    var reservesTopTrailingSpace = false
    let addHighlight: (NSRange, String, HighlightColor) -> Void
    let deleteHighlight: (NSRange) -> Void

    var body: some View {
        #if canImport(UIKit)
        SelectableTextView(
            text: text,
            prefix: prefix,
            textSize: textSize,
            lineSpacing: lineSpacing,
            readerFont: readerFont,
            customFontName: customFontName,
            layoutDirection: layoutDirection,
            highlights: highlights,
            reservesTopTrailingSpace: reservesTopTrailingSpace,
            addHighlight: addHighlight,
            deleteHighlight: deleteHighlight
        )
        #else
        Text(attributedText)
            .font(readerFont.font(size: textSize, customName: customFontName))
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
            .environment(\.layoutDirection, layoutDirection)
            .textSelection(.enabled)
        #endif
    }

    private var attributedText: AttributedString {
        var attributed = AttributedString(text)
        let nsText = text as NSString

        for highlight in highlights {
            let range = NSRange(location: highlight.startLocation, length: highlight.length)
            guard NSMaxRange(range) <= nsText.length,
                  let stringRange = Range(range, in: text),
                  let attributedRange = Range(stringRange, in: attributed),
                  let color = HighlightColor(rawValue: highlight.colorRawValue) else {
                continue
            }
            attributed[attributedRange].backgroundColor = color.color.opacity(0.45)
        }

        return attributed
    }
}

#if canImport(UIKit)
struct SelectableTextView: UIViewRepresentable {
    let text: String
    let prefix: String
    let textSize: Double
    let lineSpacing: CGFloat
    let readerFont: ReaderFont
    let customFontName: String?
    let layoutDirection: LayoutDirection
    let highlights: [MTTextHighlight]
    let reservesTopTrailingSpace: Bool
    let addHighlight: (NSRange, String, HighlightColor) -> Void
    let deleteHighlight: (NSRange) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        textView.attributedText = makeAttributedString()
        textView.textAlignment = layoutDirection == .rightToLeft ? .right : .natural
        textView.semanticContentAttribute = layoutDirection == .rightToLeft ? .forceRightToLeft : .forceLeftToRight
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width - 72
        uiView.textContainer.exclusionPaths = reservesTopTrailingSpace
            ? [UIBezierPath(rect: CGRect(x: width - 34, y: 0, width: 34, height: 34))]
            : []
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func makeAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: prefix + text)
        let prefixLength = (prefix as NSString).length
        let fullRange = NSRange(location: 0, length: ((prefix + text) as NSString).length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.alignment = layoutDirection == .rightToLeft ? .right : .natural
        paragraph.baseWritingDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight

        attributed.addAttributes(
            [
                .font: readerFont.uiFont(size: textSize, customName: customFontName),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ],
            range: fullRange
        )

        if prefixLength > 0 {
            attributed.addAttribute(.foregroundColor, value: UIColor(SefariaStyle.green), range: NSRange(location: 0, length: prefixLength))
        }

        for highlight in highlights {
            let range = NSRange(location: highlight.startLocation + prefixLength, length: highlight.length)
            guard NSMaxRange(range) <= fullRange.length,
                  let color = HighlightColor(rawValue: highlight.colorRawValue) else {
                continue
            }
            attributed.addAttribute(.backgroundColor, value: UIColor(color.color.opacity(0.45)), range: range)
        }

        return attributed
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectableTextView

        init(parent: SelectableTextView) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            let prefixLength = (parent.prefix as NSString).length
            let contentRange = NSRange(location: max(range.location - prefixLength, 0), length: max(range.length - max(prefixLength - range.location, 0), 0))
            guard contentRange.length > 0,
                  let textRange = Range(range, in: textView.text),
                  !String(textView.text[textRange]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return UIMenu(children: suggestedActions)
            }

            let intersectsExistingHighlight = parent.highlights.contains { $0.range.intersects(contentRange) }

            let colorActions = HighlightColor.allCases.map { color in
                UIAction(title: color.title) { [weak textView] _ in
                    guard let textView,
                          let selectedRange = Range(range, in: textView.text) else {
                        return
                    }
                    let selectedText = String(textView.text[selectedRange]).dropFirst(max(prefixLength - range.location, 0))
                    self.parent.addHighlight(contentRange, String(selectedText), color)
                }
            }

            let highlightMenu = UIMenu(
                title: intersectsExistingHighlight ? "Изменить цвет" : "Выделить",
                image: UIImage(systemName: "highlighter"),
                children: colorActions
            )
            var actions = suggestedActions + [highlightMenu]

            if intersectsExistingHighlight {
                actions.append(
                    UIAction(title: "Убрать выделение", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                        self.parent.deleteHighlight(contentRange)
                    }
                )
            }

            return UIMenu(children: actions)
        }

    }
}

private extension ReaderFont {
    func uiFont(size: Double, customName: String? = nil) -> UIFont {
        let pointSize = CGFloat(size)

        switch self {
        case .times:
            return UIFont(name: "Times New Roman", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .arial:
            return UIFont(name: "Arial", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .georgia:
            return UIFont(name: "Georgia", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .helvetica:
            return UIFont(name: "Helvetica Neue", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .avenir:
            return UIFont(name: "Avenir Next", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .palatino:
            return UIFont(name: "Palatino", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .baskerville:
            return UIFont(name: "Baskerville", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .charter:
            return UIFont(name: "Charter", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .hoefler:
            return UIFont(name: "Hoefler Text", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .optima:
            return UIFont(name: "Optima", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .didot:
            return UIFont(name: "Didot", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .verdana:
            return UIFont(name: "Verdana", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .tahoma:
            return UIFont(name: "Tahoma", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .trebuchet:
            return UIFont(name: "Trebuchet MS", size: pointSize) ?? .systemFont(ofSize: pointSize)
        case .system:
            return .systemFont(ofSize: pointSize)
        case .rounded:
            return .systemFont(ofSize: pointSize)
        case .monospaced:
            return .monospacedSystemFont(ofSize: pointSize, weight: .regular)
        case .custom:
            if let customName, let font = UIFont(name: customName, size: pointSize) {
                return font
            }
            return UIFont(name: "Times New Roman", size: pointSize) ?? .systemFont(ofSize: pointSize)
        }
    }
}
#endif
