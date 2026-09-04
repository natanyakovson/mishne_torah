import Foundation
import SwiftData
import SwiftUI

@Model
final class MTBook {
    @Attribute(.unique) var id: UUID
    var order: Int
    var titleHebrew: String
    var titleRussian: String
    @Relationship(deleteRule: .cascade, inverse: \MTSection.book) var sections: [MTSection]

    init(id: UUID = UUID(), order: Int, titleHebrew: String, titleRussian: String, sections: [MTSection] = []) {
        self.id = id
        self.order = order
        self.titleHebrew = titleHebrew
        self.titleRussian = titleRussian
        self.sections = sections
    }
}

@Model
final class MTSection {
    @Attribute(.unique) var id: UUID
    var order: Int
    var titleHebrew: String
    var titleRussian: String
    var book: MTBook?
    @Relationship(deleteRule: .cascade, inverse: \MTChapter.section) var chapters: [MTChapter]

    init(id: UUID = UUID(), order: Int, titleHebrew: String, titleRussian: String, chapters: [MTChapter] = []) {
        self.id = id
        self.order = order
        self.titleHebrew = titleHebrew
        self.titleRussian = titleRussian
        self.chapters = chapters
    }
}

@Model
final class MTChapter {
    @Attribute(.unique) var id: UUID
    var number: Int
    var section: MTSection?
    @Relationship(deleteRule: .cascade, inverse: \MTHalakhah.chapter) var halakhot: [MTHalakhah]

    init(id: UUID = UUID(), number: Int, halakhot: [MTHalakhah] = []) {
        self.id = id
        self.number = number
        self.halakhot = halakhot
    }
}

@Model
final class MTHalakhah {
    @Attribute(.unique) var id: UUID
    var number: Int
    var hebrewText: String
    var russianText: String?
    var notesJSON: String?
    var chapter: MTChapter?

    init(id: UUID = UUID(), number: Int, hebrewText: String, russianText: String? = nil, notes: [String] = []) {
        self.id = id
        self.number = number
        self.hebrewText = hebrewText
        self.russianText = russianText
        self.notesJSON = Self.encodeNotes(notes)
    }

    private static func encodeNotes(_ notes: [String]) -> String? {
        guard !notes.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(notes) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

@Model
final class MTBookmark {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var note: String
    var halakhah: MTHalakhah?

    init(id: UUID = UUID(), createdAt: Date = .now, note: String = "", halakhah: MTHalakhah? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.note = note
        self.halakhah = halakhah
    }
}

@Model
final class MTReadingHistory {
    @Attribute(.unique) var id: UUID
    var lastReadAt: Date
    var halakhah: MTHalakhah?

    init(id: UUID = UUID(), lastReadAt: Date = .now, halakhah: MTHalakhah? = nil) {
        self.id = id
        self.lastReadAt = lastReadAt
        self.halakhah = halakhah
    }
}

@Model
final class MTTextHighlight {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var colorRawValue: String
    var selectedText: String
    var startLocation: Int
    var length: Int
    var languageRawValue: String
    var halakhah: MTHalakhah?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        colorRawValue: String = HighlightColor.yellow.rawValue,
        selectedText: String = "",
        startLocation: Int = 0,
        length: Int = 0,
        languageRawValue: String = ReaderLanguage.russian.rawValue,
        halakhah: MTHalakhah? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.colorRawValue = colorRawValue
        self.selectedText = selectedText
        self.startLocation = startLocation
        self.length = length
        self.languageRawValue = languageRawValue
        self.halakhah = halakhah
    }
}

@Model
final class MTReaderSettings {
    @Attribute(.unique) var id: UUID
    var textSize: Double
    var themeRawValue: String
    var readerLanguageRawValue: String
    var readerFontRawValue: String?
    var customFontName: String?
    var customFontDisplayName: String?
    var customFontFileName: String?
    var readingCycleRawValue: String?

    init(
        id: UUID = UUID(),
        textSize: Double = 24,
        themeRawValue: String = ReaderTheme.system.rawValue,
        readerLanguageRawValue: String = ReaderLanguage.russian.rawValue,
        readerFontRawValue: String = ReaderFont.times.rawValue,
        customFontName: String? = nil,
        customFontDisplayName: String? = nil,
        customFontFileName: String? = nil,
        readingCycleRawValue: String = ReadingCycle.none.rawValue
    ) {
        self.id = id
        self.textSize = textSize
        self.themeRawValue = themeRawValue
        self.readerLanguageRawValue = readerLanguageRawValue
        self.readerFontRawValue = readerFontRawValue
        self.customFontName = customFontName
        self.customFontDisplayName = customFontDisplayName
        self.customFontFileName = customFontFileName
        self.readingCycleRawValue = readingCycleRawValue
    }
}

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: "Жёлтый"
        case .green: "Зелёный"
        case .blue: "Синий"
        case .pink: "Розовый"
        case .purple: "Фиолетовый"
        }
    }

    var color: Color {
        switch self {
        case .yellow: Color(red: 1.00, green: 0.86, blue: 0.32)
        case .green: Color(red: 0.55, green: 0.82, blue: 0.55)
        case .blue: Color(red: 0.48, green: 0.74, blue: 1.00)
        case .pink: Color(red: 1.00, green: 0.58, blue: 0.74)
        case .purple: Color(red: 0.75, green: 0.62, blue: 1.00)
        }
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        }
    }
}

enum ReaderLanguage: String, CaseIterable, Identifiable {
    case russian
    case hebrew
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .russian: "Русский"
        case .hebrew: "Иврит"
        case .both: "Оба"
        }
    }
}

enum ReaderFont: String, CaseIterable, Identifiable {
    case times = "serif"
    case arial
    case georgia
    case helvetica
    case avenir
    case palatino
    case baskerville
    case charter
    case hoefler
    case optima
    case didot
    case verdana
    case tahoma
    case trebuchet
    case system
    case rounded
    case monospaced
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .times: "Times New Roman"
        case .arial: "Arial"
        case .georgia: "Georgia"
        case .helvetica: "Helvetica Neue"
        case .avenir: "Avenir Next"
        case .palatino: "Palatino"
        case .baskerville: "Baskerville"
        case .charter: "Charter"
        case .hoefler: "Hoefler Text"
        case .optima: "Optima"
        case .didot: "Didot"
        case .verdana: "Verdana"
        case .tahoma: "Tahoma"
        case .trebuchet: "Trebuchet MS"
        case .system: "Системный"
        case .rounded: "Округлый"
        case .monospaced: "Моноширинный"
        case .custom: "Загруженный шрифт"
        }
    }

    func font(size: Double, customName: String? = nil) -> Font {
        switch self {
        case .times:
            .custom("Times New Roman", size: size)
        case .arial:
            .custom("Arial", size: size)
        case .georgia:
            .custom("Georgia", size: size)
        case .helvetica:
            .custom("Helvetica Neue", size: size)
        case .avenir:
            .custom("Avenir Next", size: size)
        case .palatino:
            .custom("Palatino", size: size)
        case .baskerville:
            .custom("Baskerville", size: size)
        case .charter:
            .custom("Charter", size: size)
        case .hoefler:
            .custom("Hoefler Text", size: size)
        case .optima:
            .custom("Optima", size: size)
        case .didot:
            .custom("Didot", size: size)
        case .verdana:
            .custom("Verdana", size: size)
        case .tahoma:
            .custom("Tahoma", size: size)
        case .trebuchet:
            .custom("Trebuchet MS", size: size)
        case .system:
            .system(size: size, weight: .regular, design: .default)
        case .rounded:
            .system(size: size, weight: .regular, design: .rounded)
        case .monospaced:
            .system(size: size, weight: .regular, design: .monospaced)
        case .custom:
            if let customName, !customName.isEmpty {
                .custom(customName, size: size)
            } else {
                .custom("Times New Roman", size: size)
            }
        }
    }
}

enum ReadingCycle: String, CaseIterable, Identifiable {
    case none
    case oneChapter
    case threeChapters

    var id: String { rawValue }

    static var selectableCases: [ReadingCycle] {
        [.oneChapter, .threeChapters]
    }

    var title: String {
        switch self {
        case .none: "Не выбрано"
        case .oneChapter: "1 глава в день"
        case .threeChapters: "3 главы в день"
        }
    }

    var shortTitle: String {
        switch self {
        case .none: ""
        case .oneChapter: "Цикл на 3 года"
        case .threeChapters: "Цикл на 1 год"
        }
    }

    var chaptersPerDay: Int {
        switch self {
        case .none: 0
        case .oneChapter: 1
        case .threeChapters: 3
        }
    }
}
