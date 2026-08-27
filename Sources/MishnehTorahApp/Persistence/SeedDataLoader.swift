import Foundation
import SwiftData

enum SeedDataLoader {
    private static let expectedMinimumHalakhot = 10_000

    static func seedIfNeeded(context: ModelContext) throws {
        let bookDescriptor = FetchDescriptor<MTBook>()
        let halakhahDescriptor = FetchDescriptor<MTHalakhah>()
        let bookCount = try context.fetchCount(bookDescriptor)
        let halakhahCount = try context.fetchCount(halakhahDescriptor)

        if bookCount == 14, halakhahCount >= expectedMinimumHalakhot {
            ensureSettingsExist(context: context)
            return
        }

        try replaceLibraryData(context: context)
        ensureSettingsExist(context: context)

        for bookSeed in SeedBook.all {
            let book = MTBook(order: bookSeed.order, titleHebrew: bookSeed.titleHebrew, titleRussian: bookSeed.titleRussian)
            context.insert(book)

            for sectionSeed in bookSeed.sections {
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
                            russianText: halakhahSeed.russianText
                        )
                        halakhah.chapter = chapter
                        chapter.halakhot.append(halakhah)
                        context.insert(halakhah)
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
