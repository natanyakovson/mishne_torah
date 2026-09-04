import Foundation
import SwiftData

enum SeedDataLoader {
    private static let expectedHalakhot = 15_066

    static func seedIfNeeded(context: ModelContext) async throws {
        let bookDescriptor = FetchDescriptor<MTBook>()
        let halakhahDescriptor = FetchDescriptor<MTHalakhah>()
        let bookCount = try context.fetchCount(bookDescriptor)
        let halakhahCount = try context.fetchCount(halakhahDescriptor)

        if bookCount == 14, halakhahCount == expectedHalakhot {
            ensureSettingsExist(context: context)
            return
        }

        try replaceLibraryData(context: context)
        ensureSettingsExist(context: context)

        var insertedHalakhot = 0
        for bookSeed in SeedBook.all {
            try Task.checkCancellation()
            let book = MTBook(order: bookSeed.order, titleHebrew: bookSeed.titleHebrew, titleRussian: bookSeed.titleRussian)
            context.insert(book)

            for sectionSeed in bookSeed.sections {
                try Task.checkCancellation()
                let section = MTSection(order: sectionSeed.order, titleHebrew: sectionSeed.titleHebrew, titleRussian: sectionSeed.titleRussian)
                section.book = book
                book.sections.append(section)
                context.insert(section)

                for chapterSeed in sectionSeed.chapters {
                    let chapter = MTChapter(number: chapterSeed.number)
                    chapter.section = section
                    section.chapters.append(chapter)
                    context.insert(chapter)

                    for halakhahSeed in chapterSeed.halakhot {
                        let halakhah = MTHalakhah(
                            number: halakhahSeed.number,
                            hebrewText: halakhahSeed.hebrewText,
                            russianText: halakhahSeed.russianText,
                            notes: halakhahSeed.notes
                        )
                        halakhah.chapter = chapter
                        chapter.halakhot.append(halakhah)
                        context.insert(halakhah)
                        insertedHalakhot += 1

                        if insertedHalakhot.isMultiple(of: 500) {
                            try context.save()
                            await Task.yield()
                        }
                    }
                }
            }
        }

        try context.save()
    }

    private static func ensureSettingsExist(context: ModelContext) {
        let descriptor = FetchDescriptor<MTReaderSettings>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            context.insert(MTReaderSettings())
        }
    }

    private static func replaceLibraryData(context: ModelContext) throws {
        for bookmark in try context.fetch(FetchDescriptor<MTBookmark>()) {
            context.delete(bookmark)
        }
        for history in try context.fetch(FetchDescriptor<MTReadingHistory>()) {
            context.delete(history)
        }
        for book in try context.fetch(FetchDescriptor<MTBook>()) {
            context.delete(book)
        }
        try context.save()
    }
}

struct SeedBook: Decodable {
    let order: Int
    let titleHebrew: String
    let titleRussian: String
    let sections: [SeedSection]

    static var all: [SeedBook] {
        guard let url = Bundle.seedData.url(forResource: "seed_books", withExtension: "json") else {
            return fallback
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([SeedBook].self, from: data)
        } catch {
            return fallback
        }
    }
}

private extension Bundle {
    static var seedData: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}

struct SeedSection: Decodable {
    let order: Int
    let titleHebrew: String
    let titleRussian: String
    let chapters: [SeedChapter]
}

struct SeedChapter: Decodable {
    let number: Int
    let halakhot: [SeedHalakhah]
}

struct SeedHalakhah: Decodable {
    let number: Int
    let hebrewText: String
    let russianText: String?
    let notes: [String]

    private enum CodingKeys: String, CodingKey {
        case number
        case hebrewText
        case russianText
        case notes
    }

    init(number: Int, hebrewText: String, russianText: String?, notes: [String] = []) {
        self.number = number
        self.hebrewText = hebrewText
        self.russianText = russianText
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        hebrewText = try container.decode(String.self, forKey: .hebrewText)
        russianText = try container.decodeIfPresent(String.self, forKey: .russianText)
        notes = try container.decodeIfPresent([String].self, forKey: .notes) ?? []
    }
}

private extension SeedBook {
    static let fallback: [SeedBook] = [
        SeedBook(order: 1, titleHebrew: "ספר המדע", titleRussian: "Книга знания", sections: [
            SeedSection(order: 1, titleHebrew: "הלכות יסודי התורה", titleRussian: "Законы основ Торы", chapters: [
                SeedChapter(number: 1, halakhot: [
                    SeedHalakhah(
                        number: 1,
                        hebrewText: "יסוד היסודות ועמוד החכמות לידע שיש שם מצוי ראשון.",
                        russianText: "Основа основ и столп мудростей - знать, что существует Первосущий."
                    )
                ])
            ])
        ])
    ]
}
