import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ReaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appNavigation: AppNavigationState
    @Query private var settings: [MTReaderSettings]
    @Query private var bookmarks: [MTBookmark]
    @Query(sort: \MTTextHighlight.createdAt, order: .reverse) private var highlights: [MTTextHighlight]
    @State private var didRecordReading = false
    @State private var activeSheet: ReaderSheet?
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
            .padding(.horizontal, 10)
            .padding(.vertical, 22)
            .padding(.bottom, 96)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .background(SefariaStyle.background(for: colorScheme))
        .navigationTitle("Глава \(chapter.number)")
        .safeAreaInset(edge: .bottom) {
            ReaderBottomBar(
                chapterTitle: "Глава \(chapter.number)",
                isCurrentChapterBookmarked: isCurrentChapterBookmarked,
                openContents: { activeSheet = .contents },
                openSearch: { activeSheet = .search },
                openSettings: { activeSheet = .settings },
                toggleBookmark: toggleCurrentChapterBookmark,
                returnHome: returnToLibraryRoot
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

    private var isCurrentChapterBookmarked: Bool {
        guard let firstHalakhah = chapter.sortedHalakhot.first else { return false }
        return isBookmarked(firstHalakhah)
    }

    private func toggleCurrentChapterBookmark() {
        guard let firstHalakhah = chapter.sortedHalakhot.first else { return }
        toggleBookmark(for: firstHalakhah)
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

    private func returnToLibraryRoot() {
        appNavigation.selectedTab = .library
        NotificationCenter.default.post(name: .returnToLibraryRoot, object: nil)
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
    let chapterTitle: String
    let isCurrentChapterBookmarked: Bool
    let openContents: () -> Void
    let openSearch: () -> Void
    let openSettings: () -> Void
    let toggleBookmark: () -> Void
    let returnHome: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if isExpanded {
                VStack(alignment: .trailing, spacing: 8) {
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

                    expandedButton(title: "Главная", subtitle: nil, systemImage: "house") {
                        isExpanded = false
                        returnHome()
                    }

                    expandedButton(
                        title: isCurrentChapterBookmarked ? "Убрать закладку" : "Добавить закладку",
                        subtitle: nil,
                        systemImage: isCurrentChapterBookmarked ? "bookmark.fill" : "bookmark"
                    ) {
                        isExpanded = false
                        toggleBookmark()
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
                    .font(.title2.weight(.semibold))
                    .frame(width: 58, height: 58)
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
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(SefariaStyle.deepGreen)
                }
                Spacer(minLength: 12)
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(systemImage == "bookmark.fill" ? SefariaStyle.gold : .black)
                    .frame(width: 34)
            }
            .frame(width: 314)
            .frame(height: 52)
            .padding(.horizontal, 18)
            .background(.thinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
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
    @Environment(\.colorScheme) private var colorScheme
    let chapter: MTChapter
    let previousChapter: MTChapter?
    let nextChapter: MTChapter?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let section = chapter.section, let book = section.book {
                NavigationLink {
                    ChapterGridView(section: section)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.titleRussian)
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(SefariaStyle.green)
                        Text(section.titleRussian)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(book.titleHebrew)
                            .font(.title3.weight(.regular))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .environment(\.layoutDirection, .rightToLeft)
                        Text("Глава \(chapter.number)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SefariaStyle.panelBackground(for: colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(halakhah.number)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SefariaStyle.green)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 12) {
                if readerLanguage != .hebrew {
                    SelectableHalakhahText(
                        text: halakhah.russianDisplayText,
                        textSize: textSize,
                        lineSpacing: 9,
                        readerFont: readerFont,
                        customFontName: customFontName,
                        layoutDirection: .leftToRight,
                        highlights: russianHighlights
                    ) { range, selectedText, color in
                        addHighlight(range, selectedText, .russian, color)
                    } deleteHighlight: { range in
                        deleteHighlight(range, .russian)
                    }
                }

                if readerLanguage == .both {
                    Text("Иврит")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if readerLanguage != .russian {
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                toggleBookmark()
            } label: {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(isBookmarked ? SefariaStyle.gold : SefariaStyle.green)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .help(isBookmarked ? "Убрать из закладок" : "Добавить в закладки")
            .accessibilityLabel(isBookmarked ? "Убрать из закладок" : "Добавить в закладки")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 0)
        .contextMenu {
            Button(isBookmarked ? "Убрать закладку" : "Добавить закладку") {
                toggleBookmark()
            }
        }
    }
}

struct SelectableHalakhahText: View {
    let text: String
    let textSize: Double
    let lineSpacing: CGFloat
    let readerFont: ReaderFont
    let customFontName: String?
    let layoutDirection: LayoutDirection
    let highlights: [MTTextHighlight]
    let addHighlight: (NSRange, String, HighlightColor) -> Void
    let deleteHighlight: (NSRange) -> Void

    var body: some View {
        #if canImport(UIKit)
        SelectableTextView(
            text: text,
            textSize: textSize,
            lineSpacing: lineSpacing,
            readerFont: readerFont,
            customFontName: customFontName,
            layoutDirection: layoutDirection,
            highlights: highlights,
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
    let textSize: Double
    let lineSpacing: CGFloat
    let readerFont: ReaderFont
    let customFontName: String?
    let layoutDirection: LayoutDirection
    let highlights: [MTTextHighlight]
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
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func makeAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
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

        for highlight in highlights {
            let range = NSRange(location: highlight.startLocation, length: highlight.length)
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
            guard range.length > 0,
                  let textRange = Range(range, in: textView.text),
                  !String(textView.text[textRange]).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return UIMenu(children: suggestedActions)
            }

            let intersectsExistingHighlight = parent.highlights.contains { $0.range.intersects(range) }

            let colorActions = HighlightColor.allCases.map { color in
                UIAction(title: color.title) { [weak textView] _ in
                    guard let textView,
                          let selectedRange = Range(range, in: textView.text) else {
                        return
                    }
                    self.parent.addHighlight(range, String(textView.text[selectedRange]), color)
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
                        self.parent.deleteHighlight(range)
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
