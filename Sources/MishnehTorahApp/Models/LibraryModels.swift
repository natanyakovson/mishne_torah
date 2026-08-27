import Foundation
import SwiftData

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
    var chapter: MTChapter?

    init(id: UUID = UUID(), number: Int, hebrewText: String, russianText: String? = nil) {
        self.id = id
        self.number = number
        self.hebrewText = hebrewText
        self.russianText = russianText
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
final class MTReaderSettings {
    @Attribute(.unique) var id: UUID
    var textSize: Double
    var themeRawValue: String
    var readerLanguageRawValue: String

    init(
        id: UUID = UUID(),
        textSize: Double = 24,
        themeRawValue: String = ReaderTheme.system.rawValue,
        readerLanguageRawValue: String = ReaderLanguage.russian.rawValue
    ) {
        self.id = id
        self.textSize = textSize
        self.themeRawValue = themeRawValue
        self.readerLanguageRawValue = readerLanguageRawValue
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
