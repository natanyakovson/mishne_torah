import Foundation
import SwiftData

enum TextImportService {
    static func importBooks(from data: Data, context: ModelContext) throws {
        let books = try JSONDecoder().decode([SeedBook].self, from: data)

        for bookSeed in books {
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
}
