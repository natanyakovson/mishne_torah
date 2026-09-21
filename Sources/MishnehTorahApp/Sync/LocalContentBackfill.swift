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
    static func backfillContentIDs(context: ModelContext, seeds: [SeedBook]? = nil) throws -> Report {
        var report = Report()
        if seeds == nil,
           try context.fetchCount(FetchDescriptor<MTBook>(predicate: #Predicate { $0.contentID == nil })) == 0,
           try context.fetchCount(FetchDescriptor<MTSection>(predicate: #Predicate { $0.contentID == nil })) == 0,
           try context.fetchCount(FetchDescriptor<MTChapter>(predicate: #Predicate { $0.contentID == nil })) == 0,
           try context.fetchCount(FetchDescriptor<MTHalakhah>(predicate: #Predicate { $0.contentID == nil })) == 0 {
            return report
        }
        let localBooks = try context.fetch(FetchDescriptor<MTBook>()).sorted { $0.order < $1.order }
        let booksByOrder = Dictionary(grouping: localBooks, by: \.order)

        for seedBook in seeds ?? SeedBook.all {
            guard let book = single(booksByOrder[seedBook.order]) else {
                report.issues.append("book order \(seedBook.order): no unique local match")
                continue
            }

            let bookContentID = ContentIDGenerator.bookID(order: seedBook.order)
            if book.contentID == nil {
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
                if section.contentID == nil {
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
                    if chapter.contentID == nil {
                        chapter.contentID = chapterContentID
                        report.chaptersUpdated += 1
                    }
                    if chapter.m770ID == nil { chapter.m770ID = m770ID }
                    if chapter.m770URL == nil { chapter.m770URL = seedChapter.m770Url }

                    guard chapter.halakhot.contains(where: { $0.contentID == nil }) else { continue }

                    var lawOccurrences: [Int: Int] = [:]
                    var unmatchedHalakhot = chapter.halakhot
                    guard unmatchedHalakhot.count == seedChapter.halakhot.count else {
                        report.issues.append("\(chapterContentID): halakhah count mismatch")
                        continue
                    }

                    for (index, seedHalakhah) in seedChapter.halakhot.enumerated() {
                        let partIndex = lawOccurrences[seedHalakhah.number, default: 0]
                        lawOccurrences[seedHalakhah.number] = partIndex + 1
                        let halakhahContentID = ContentIDGenerator.halakhahID(m770ID: m770ID, lawNumber: seedHalakhah.number, partIndex: partIndex)
                        if let existing = unmatchedHalakhot.firstIndex(where: { $0.contentID == halakhahContentID }) {
                            unmatchedHalakhot.remove(at: existing)
                            continue
                        }
                        guard let matchIndex = unmatchedHalakhot.firstIndex(where: {
                            $0.contentID == nil && $0.number == seedHalakhah.number
                                && $0.hebrewText == seedHalakhah.hebrewText
                                && ($0.russianText ?? "") == (seedHalakhah.russianText ?? "")
                        }) else {
                            report.issues.append("\(chapterContentID) law index \(index + 1): no text match")
                            continue
                        }
                        let halakhah = unmatchedHalakhot.remove(at: matchIndex)

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
