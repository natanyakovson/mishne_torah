import Foundation
import SwiftData

@MainActor
final class ContentSyncService {
    enum SyncError: Error {
        case missingParent(String)
    }

    static let shared = ContentSyncService()

    private let remote: RemoteContentFetching?
    private let stateStore: SyncStateStoring
    private let logger: SyncLogging

    init(
        remote: RemoteContentFetching? = ContentSyncService.makeDefaultRemote(),
        stateStore: SyncStateStoring = UserDefaultsSyncStateStore(),
        logger: SyncLogging = ConsoleSyncLogger()
    ) {
        self.remote = remote
        self.stateStore = stateStore
        self.logger = logger
    }

    private static func makeDefaultRemote() -> RemoteContentFetching? {
        guard let config = SupabaseConfig.bundled else { return nil }
        return RemoteContentService(config: config)
    }

    func syncNow(context: ModelContext) async {
        do {
            let backfillReport = try LocalContentBackfill.backfillContentIDs(context: context)
            if !backfillReport.issues.isEmpty {
                logger.debug("backfill issues: \(backfillReport.issues.count)")
            }

            guard let remote else {
                logger.debug("skipped: Supabase publishable key is not configured")
                return
            }

            var state = stateStore.load()
            logger.debug("local version: \(state.lastContentVersion)")

            let meta = try await remote.fetchContentMeta()
            logger.debug("remote version: \(meta.contentVersion)")

            guard meta.contentVersion > state.lastContentVersion else {
                state.lastSuccessfulSyncAt = meta.updatedAt
                state.schemaVersion = meta.schemaVersion
                stateStore.save(state)
                logger.debug("completed: already up to date")
                return
            }

            logger.debug("fetching changes...")
            let changes = try await remote.fetchChanges(
                localVersion: state.lastContentVersion,
                updatedAfter: state.lastSuccessfulSyncAt
            )
            logger.debug("books changed: \(changes.books.count)")
            logger.debug("sections changed: \(changes.sections.count)")
            logger.debug("chapters changed: \(changes.chapters.count)")
            logger.debug("halakhot changed: \(changes.halakhot.count)")

            try apply(changes: changes, context: context)
            try context.save()

            state.lastContentVersion = meta.contentVersion
            state.lastSuccessfulSyncAt = meta.updatedAt
            state.schemaVersion = meta.schemaVersion
            stateStore.save(state)
            logger.debug("completed")
        } catch {
            logger.debug("failed: \(error.localizedDescription)")
        }
    }

    private func apply(changes: RemoteContentChanges, context: ModelContext) throws {
        var booksByContentID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MTBook>()).compactMap { book in
            book.contentID.map { ($0, book) }
        })
        var booksByRemoteID = Dictionary(uniqueKeysWithValues: booksByContentID.values.compactMap { book in
            book.remoteID.map { ($0, book) }
        })

        for dto in changes.books {
            let book = booksByContentID[dto.contentID] ?? MTBook(order: dto.sortOrder, titleHebrew: dto.titleHebrew, titleRussian: dto.titleRussian)
            if booksByContentID[dto.contentID] == nil {
                context.insert(book)
            }
            book.contentID = dto.contentID
            book.remoteID = dto.id
            book.contentVersion = dto.contentVersion
            book.deletedAt = parseDate(dto.deletedAt)
            if dto.deletedAt == nil, dto.isPublished {
                book.order = dto.sortOrder
                book.titleHebrew = dto.titleHebrew
                book.titleRussian = dto.titleRussian
            }
            booksByContentID[dto.contentID] = book
            booksByRemoteID[dto.id] = book
        }

        var sectionsByContentID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MTSection>()).compactMap { section in
            section.contentID.map { ($0, section) }
        })
        var sectionsByRemoteID = Dictionary(uniqueKeysWithValues: sectionsByContentID.values.compactMap { section in
            section.remoteID.map { ($0, section) }
        })

        for dto in changes.sections {
            guard let book = booksByRemoteID[dto.bookID] else {
                throw SyncError.missingParent("book \(dto.bookID) for section \(dto.contentID)")
            }
            let section = sectionsByContentID[dto.contentID] ?? MTSection(order: dto.sortOrder, titleHebrew: dto.titleHebrew, titleRussian: dto.titleRussian)
            if sectionsByContentID[dto.contentID] == nil {
                context.insert(section)
            }
            section.contentID = dto.contentID
            section.remoteID = dto.id
            section.contentVersion = dto.contentVersion
            section.deletedAt = parseDate(dto.deletedAt)
            section.book = book
            if !book.sections.contains(where: { $0.id == section.id }) {
                book.sections.append(section)
            }
            if dto.deletedAt == nil, dto.isPublished {
                section.order = dto.sortOrder
                section.titleHebrew = dto.titleHebrew
                section.titleRussian = dto.titleRussian
            }
            sectionsByContentID[dto.contentID] = section
            sectionsByRemoteID[dto.id] = section
        }

        var chaptersByContentID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MTChapter>()).compactMap { chapter in
            chapter.contentID.map { ($0, chapter) }
        })
        var chaptersByRemoteID = Dictionary(uniqueKeysWithValues: chaptersByContentID.values.compactMap { chapter in
            chapter.remoteID.map { ($0, chapter) }
        })

        for dto in changes.chapters {
            guard let section = sectionsByRemoteID[dto.sectionID] else {
                throw SyncError.missingParent("section \(dto.sectionID) for chapter \(dto.contentID)")
            }
            let chapter = chaptersByContentID[dto.contentID] ?? MTChapter(number: dto.chapterNumber)
            if chaptersByContentID[dto.contentID] == nil {
                context.insert(chapter)
            }
            chapter.contentID = dto.contentID
            chapter.remoteID = dto.id
            chapter.contentVersion = dto.contentVersion
            chapter.deletedAt = parseDate(dto.deletedAt)
            chapter.section = section
            if !section.chapters.contains(where: { $0.id == chapter.id }) {
                section.chapters.append(chapter)
            }
            if dto.deletedAt == nil, dto.isPublished {
                chapter.number = dto.chapterNumber
                chapter.m770ID = dto.m770ID
                chapter.m770URL = dto.m770URL
            }
            chaptersByContentID[dto.contentID] = chapter
            chaptersByRemoteID[dto.id] = chapter
        }

        var halakhotByContentID = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MTHalakhah>()).compactMap { halakhah in
            halakhah.contentID.map { ($0, halakhah) }
        })

        for dto in changes.halakhot {
            guard let chapter = chaptersByRemoteID[dto.chapterID] else {
                throw SyncError.missingParent("chapter \(dto.chapterID) for halakhah \(dto.contentID)")
            }
            let halakhah = halakhotByContentID[dto.contentID] ?? MTHalakhah(number: dto.lawNumber, hebrewText: dto.textHebrew, russianText: dto.textRussian, notes: dto.notes)
            if halakhotByContentID[dto.contentID] == nil {
                context.insert(halakhah)
            }
            halakhah.contentID = dto.contentID
            halakhah.remoteID = dto.id
            halakhah.contentVersion = dto.contentVersion
            halakhah.deletedAt = parseDate(dto.deletedAt)
            halakhah.partIndex = dto.partIndex
            halakhah.sortOrder = dto.sortOrder
            halakhah.chapter = chapter
            if !chapter.halakhot.contains(where: { $0.id == halakhah.id }) {
                chapter.halakhot.append(halakhah)
            }
            if dto.deletedAt == nil, dto.isPublished {
                halakhah.number = dto.lawNumber
                halakhah.hebrewText = dto.textHebrew
                halakhah.russianText = dto.textRussian
                halakhah.notesJSON = encodeNotes(dto.notes)
            }
            halakhotByContentID[dto.contentID] = halakhah
        }
    }

    private func encodeNotes(_ notes: [String]) -> String? {
        guard !notes.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(notes) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}
