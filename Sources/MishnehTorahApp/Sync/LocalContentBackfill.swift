import Foundation
import SwiftData

enum LocalContentBackfill {
    struct Report: Equatable {
        var booksUpdated = 0
        var sectionsUpdated = 0
        var chaptersUpdated = 0
        var halakhotUpdated = 0
        var issues: [String] = []
    }

    @discardableResult
    static func backfillContentIDs(context: ModelContext, seeds: [SeedBook] = SeedBook.all) throws -> Report {
        var report = Report()
        let localBooks = try context.fetch(FetchDescriptor<MTBook>()).sorted { $0.order < $1.order }
        let booksByOrder = Dictionary(grouping: localBooks, by: \.order)

        for seedBook in seeds {
            guard let book = single(booksByOrder[seedBook.order]) else {
                report.issues.append("book order \(seedBook.order): no unique local match")
                continue
            }

            let bookContentID = ContentIDGenerator.bookID(order: seedBook.order)
            if book.contentID != bookContentID {
                book.contentID = bookContentID
                report.booksUpdated += 1
            }

            let localSections = Dictionary(grouping: book.sections, by: \.order)
            for seedSection in seedBook.sections {
                guard let section = single(localSections[seedSection.order]) else {
                    report.issues.append("\(bookContentID) section \(seedSection.order): no unique local match")
                    continue
                }

                let sectionContentID = ContentIDGenerator.sectionID(bookOrder: seedBook.order, sectionOrder: seedSection.order)
                if section.contentID != sectionContentID {
                    section.contentID = sectionContentID
                    report.sectionsUpdated += 1
                }

                let localChapters = Dictionary(grouping: section.chapters, by: \.number)
                for seedChapter in seedSection.chapters {
                    guard let chapter = single(localChapters[seedChapter.number]) else {
                        report.issues.append("\(sectionContentID) chapter \(seedChapter.number): no unique local match")
                        continue
                    }

                    let m770ID = String(seedChapter.m770Id)
                    let chapterContentID = ContentIDGenerator.chapterID(m770ID: m770ID)
                    if chapter.contentID != chapterContentID {
                        chapter.contentID = chapterContentID
                        report.chaptersUpdated += 1
                    }
                    chapter.m770ID = m770ID
                    chapter.m770URL = seedChapter.m770Url

                    var lawOccurrences: [Int: Int] = [:]
                    var unmatchedHalakhot = chapter.halakhot
                    guard unmatchedHalakhot.count == seedChapter.halakhot.count else {
                        report.issues.append("\(chapterContentID): halakhah count mismatch")
                        continue
                    }

                    for (index, seedHalakhah) in seedChapter.halakhot.enumerated() {
                        guard let matchIndex = unmatchedHalakhot.firstIndex(where: {
                            $0.number == seedHalakhah.number
                                && $0.hebrewText == seedHalakhah.hebrewText
                                && ($0.russianText ?? "") == (seedHalakhah.russianText ?? "")
                        }) else {
                            report.issues.append("\(chapterContentID) law index \(index + 1): no text match")
                            continue
                        }
                        let halakhah = unmatchedHalakhot.remove(at: matchIndex)

                        let partIndex = lawOccurrences[seedHalakhah.number, default: 0]
                        lawOccurrences[seedHalakhah.number] = partIndex + 1
                        let halakhahContentID = ContentIDGenerator.halakhahID(m770ID: m770ID, lawNumber: seedHalakhah.number, partIndex: partIndex)

                        if halakhah.contentID != halakhahContentID {
                            halakhah.contentID = halakhahContentID
                            report.halakhotUpdated += 1
                        }
                        halakhah.partIndex = partIndex
                        halakhah.sortOrder = index + 1
                    }
                }
            }
        }

        try context.save()
        return report
    }

    private static func single<T>(_ values: [T]?) -> T? {
        guard let values, values.count == 1 else { return nil }
        return values[0]
    }
}
