import SwiftData
import SwiftUI

struct ReaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [MTReaderSettings]
    let chapter: MTChapter

    private var textSize: Double {
        settings.first?.textSize ?? 24
    }

    private var readerLanguage: ReaderLanguage {
        ReaderLanguage(rawValue: settings.first?.readerLanguageRawValue ?? "") ?? .russian
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ReaderHeader(chapter: chapter)

                    ForEach(chapter.sortedHalakhot) { halakhah in
                        HalakhahCard(halakhah: halakhah, textSize: textSize, readerLanguage: readerLanguage)
                            .id(halakhah.id)
                            .onAppear {
                                recordReading(halakhah)
                            }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 22)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background(SefariaStyle.background(for: colorScheme))
            .navigationTitle("Глава \(chapter.number)")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {} label: {
                        Image(systemName: "textformat.size")
                    }
                    .help("Настройки текста")

                    Button {} label: {
                        Image(systemName: "square.split.2x1")
                    }
                    .help("Показать русский и иврит")
                }
            }
        }
    }

    private func recordReading(_ halakhah: MTHalakhah) {
        let history = MTReadingHistory(halakhah: halakhah)
        modelContext.insert(history)
        try? modelContext.save()
    }
}

struct ReaderHeader: View {
    let chapter: MTChapter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let section = chapter.section, let book = section.book {
                Text("Мишне Тора")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(SefariaStyle.green)
                Text("\(book.titleRussian) / \(section.titleRussian)")
                    .font(.title3.weight(.semibold))
                Text(book.titleHebrew)
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            Text("Глава \(chapter.number)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SefariaStyle.line)
                .frame(height: 1)
        }
    }
}

struct HalakhahCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    let halakhah: MTHalakhah
    let textSize: Double
    let readerLanguage: ReaderLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Галаха \(halakhah.number)")
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(SefariaStyle.green)
                Spacer()
                Button {
                    modelContext.insert(MTBookmark(halakhah: halakhah))
                    try? modelContext.save()
                } label: {
                    Image(systemName: "bookmark")
                        .foregroundStyle(SefariaStyle.green)
                }
                .buttonStyle(.borderless)
                .help("Добавить закладку")
            }

            if readerLanguage != .hebrew {
                Text(halakhah.russianDisplayText)
                    .font(.system(size: textSize, weight: .regular, design: .serif))
                    .lineSpacing(9)
                    .textSelection(.enabled)
            }

            if readerLanguage == .both {
                Rectangle()
                    .fill(SefariaStyle.line)
                    .frame(height: 1)
            }

            if readerLanguage != .russian {
                Text(halakhah.hebrewDisplayText)
                    .font(.system(size: textSize, weight: .regular, design: .serif))
                    .lineSpacing(8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .textSelection(.enabled)
            }

            if readerLanguage == .russian, halakhah.russianText == nil {
                Text("Русский текст для этой галахи ещё не импортирован.")
                    .font(.system(size: max(textSize - 4, 16)))
                    .foregroundStyle(.secondary)
            }

            if readerLanguage != .russian, halakhah.hebrewText.isEmpty {
                Text("Иврит для этой галахи не найден в источнике.")
                    .font(.system(size: max(textSize - 4, 16)))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 18)
        .background(SefariaStyle.panelBackground(for: colorScheme))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SefariaStyle.green)
                .frame(width: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 2)
                .stroke(SefariaStyle.line.opacity(0.75), lineWidth: 1)
        }
    }
}
