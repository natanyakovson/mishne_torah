import Foundation
import SwiftData

enum TextImportService {
    static func importBooks(from data: Data, context: ModelContext) throws {
        let books = try JSONDecoder().decode([SeedBook].self, from: data)

        for bookSeed in books {
            let book = MTBook(order: bookSeed.order, titleHebrew: bookSeed.titleHebrew, titleRussian: bookSeed.titleRussian)
            book.contentID = ContentIDGenerator.bookID(order: bookSeed.order)
            context.insert(book)

            for sectionSeed in bookSeed.sections {
                let section = MTSection(order: sectionSeed.order, titleHebrew: sectionSeed.titleHebrew, titleRussian: sectionSeed.titleRussian)
                section.contentID = ContentIDGenerator.sectionID(bookOrder: bookSeed.order, sectionOrder: sectionSeed.order)
                section.book = book
                book.sections.append(section)
                context.insert(section)

                for chapterSeed in sectionSeed.chapters {
                    let chapter = MTChapter(number: chapterSeed.number)
                    let m770ID = String(chapterSeed.m770Id)
                    chapter.contentID = ContentIDGenerator.chapterID(m770ID: m770ID)
                    chapter.m770ID = m770ID
                    chapter.m770URL = chapterSeed.m770Url
                    chapter.section = section
                    section.chapters.append(chapter)
                    context.insert(chapter)

                    var lawOccurrences: [Int: Int] = [:]
                    for (index, halakhahSeed) in chapterSeed.halakhot.enumerated() {
                        let partIndex = lawOccurrences[halakhahSeed.number, default: 0]
                        lawOccurrences[halakhahSeed.number] = partIndex + 1
                        let halakhah = MTHalakhah(
                            number: halakhahSeed.number,
                            hebrewText: halakhahSeed.hebrewText,
                            russianText: halakhahSeed.russianText,
                            notes: halakhahSeed.notes
                        )
                        halakhah.contentID = ContentIDGenerator.halakhahID(m770ID: m770ID, lawNumber: halakhahSeed.number, partIndex: partIndex)
                        halakhah.partIndex = partIndex
                        halakhah.sortOrder = index + 1
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
