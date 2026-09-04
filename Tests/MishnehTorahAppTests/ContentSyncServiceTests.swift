import Foundation
import SwiftData
import XCTest
@testable import MishnehTorahApp

@MainActor
final class ContentSyncServiceTests: XCTestCase {
    func testSkipsDownloadWhenRemoteVersionIsNotNewer() async throws {
        let store = InMemorySyncStateStore(state: SyncState(lastContentVersion: 2, lastSuccessfulSyncAt: nil, schemaVersion: 1))
        let remote = MockRemoteContent(
            meta: RemoteContentMetaDTO(contentVersion: 2, schemaVersion: 2, updatedAt: "2026-09-04T10:00:00Z"),
            changes: .empty
        )
        let service = ContentSyncService(remote: remote, stateStore: store, logger: CapturingSyncLogger())

        await service.syncNow(context: try makeContext())

        XCTAssertEqual(remote.fetchChangesCallCount, 0)
        XCTAssertEqual(store.load().lastContentVersion, 2)
        XCTAssertEqual(store.load().lastSuccessfulSyncAt, "2026-09-04T10:00:00Z")
    }

    func testBackfillsStableContentIDs() throws {
        let context = try makeContext()
        let book = MTBook(order: 1, titleHebrew: "ספר המדע", titleRussian: "Книга знания")
        let section = MTSection(order: 1, titleHebrew: "הלכות יסודי התורה", titleRussian: "Законы основ Торы")
        let chapter = MTChapter(number: 1)
        let first = MTHalakhah(number: 1, hebrewText: "א", russianText: "А")
        let second = MTHalakhah(number: 1, hebrewText: "ב", russianText: "Б")
        section.book = book
        book.sections = [section]
        chapter.section = section
        section.chapters = [chapter]
        first.chapter = chapter
        second.chapter = chapter
        chapter.halakhot = [second, first]
        [book, section, chapter, first, second].forEach { context.insert($0) }

        let seed = SeedBook(order: 1, titleHebrew: "ספר המדע", titleRussian: "Книга знания", sections: [
            SeedSection(order: 1, titleHebrew: "הלכות יסודי התורה", titleRussian: "Законы основ Торы", chapters: [
                SeedChapter(number: 1, m770Id: 13, m770Url: nil, halakhot: [
                    SeedHalakhah(number: 1, hebrewText: "א", russianText: "А"),
                    SeedHalakhah(number: 1, hebrewText: "ב", russianText: "Б")
                ])
            ])
        ])

        let report = try LocalContentBackfill.backfillContentIDs(context: context, seeds: [seed])

        XCTAssertTrue(report.issues.isEmpty)
        XCTAssertEqual(book.contentID, "book:1")
        XCTAssertEqual(section.contentID, "section:1:1")
        XCTAssertEqual(chapter.contentID, "chapter:13")
        XCTAssertEqual(first.contentID, "halakha:13:1:0")
        XCTAssertEqual(second.contentID, "halakha:13:1:1")
        XCTAssertEqual(first.partIndex, 0)
        XCTAssertEqual(second.partIndex, 1)
    }

    func testRepeatedSyncWithoutChangesDoesNotFetchRows() async throws {
        let store = InMemorySyncStateStore(state: SyncState(lastContentVersion: 1, lastSuccessfulSyncAt: "2026-09-04T10:00:00Z", schemaVersion: 2))
        let remote = MockRemoteContent(
            meta: RemoteContentMetaDTO(contentVersion: 1, schemaVersion: 2, updatedAt: "2026-09-04T10:00:00Z"),
            changes: .empty
        )
        let service = ContentSyncService(remote: remote, stateStore: store, logger: CapturingSyncLogger())

        await service.syncNow(context: try makeContext())

        XCTAssertEqual(remote.fetchChangesCallCount, 0)
        XCTAssertEqual(store.load().lastContentVersion, 1)
    }

    func testNetworkErrorDoesNotAdvanceLocalVersion() async throws {
        let store = InMemorySyncStateStore(state: SyncState(lastContentVersion: 1, lastSuccessfulSyncAt: nil, schemaVersion: 1))
        let remote = MockRemoteContent(error: URLError(.notConnectedToInternet))
        let service = ContentSyncService(remote: remote, stateStore: store, logger: CapturingSyncLogger())

        await service.syncNow(context: try makeContext())

        XCTAssertEqual(store.load().lastContentVersion, 1)
        XCTAssertNil(store.load().lastSuccessfulSyncAt)
    }

    func testSoftDeleteMarksLocalRowWithoutDeletingIt() async throws {
        let context = try makeContext()
        let book = MTBook(order: 1, titleHebrew: "ספר המדע", titleRussian: "Книга знания")
        book.contentID = "book:1"
        context.insert(book)
        try context.save()

        let store = InMemorySyncStateStore()
        let remote = MockRemoteContent(
            meta: RemoteContentMetaDTO(contentVersion: 2, schemaVersion: 2, updatedAt: "2026-09-04T12:00:00Z"),
            changes: RemoteContentChanges(
                books: [RemoteBookDTO(id: "remote-book-1", contentID: "book:1", titleRussian: "Книга знания", titleHebrew: "ספר המדע", sortOrder: 1, contentVersion: 2, isPublished: false, deletedAt: "2026-09-04T11:59:00Z", updatedAt: "2026-09-04T11:59:00Z")],
                sections: [],
                chapters: [],
                halakhot: []
            )
        )
        let service = ContentSyncService(remote: remote, stateStore: store, logger: CapturingSyncLogger())

        await service.syncNow(context: context)

        let books = try context.fetch(FetchDescriptor<MTBook>())
        XCTAssertEqual(books.count, 1)
        XCTAssertNotNil(books[0].deletedAt)
        XCTAssertEqual(store.load().lastContentVersion, 2)
    }

    func testSuccessfulSyncAppliesHierarchyAndAdvancesVersion() async throws {
        let context = try makeContext()
        let store = InMemorySyncStateStore()
        let remote = MockRemoteContent(
            meta: RemoteContentMetaDTO(contentVersion: 1, schemaVersion: 2, updatedAt: "2026-09-04T12:00:00Z"),
            changes: sampleChanges()
        )
        let service = ContentSyncService(remote: remote, stateStore: store, logger: CapturingSyncLogger())

        await service.syncNow(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<MTBook>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MTSection>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MTChapter>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MTHalakhah>()).count, 1)
        XCTAssertEqual(store.load().lastContentVersion, 1)
    }

    private func makeContext() throws -> ModelContext {
        try PersistenceController(inMemory: true).container.mainContext
    }

    private func sampleChanges() -> RemoteContentChanges {
        RemoteContentChanges(
            books: [RemoteBookDTO(id: "book-uuid", contentID: "book:1", titleRussian: "Книга знания", titleHebrew: "ספר המדע", sortOrder: 1, contentVersion: 1, isPublished: true, deletedAt: nil, updatedAt: "2026-09-04T10:00:00Z")],
            sections: [RemoteSectionDTO(id: "section-uuid", contentID: "section:1:1", bookID: "book-uuid", titleRussian: "Законы основ Торы", titleHebrew: "הלכות יסודי התורה", sortOrder: 1, contentVersion: 1, isPublished: true, deletedAt: nil, updatedAt: "2026-09-04T10:00:00Z")],
            chapters: [RemoteChapterDTO(id: "chapter-uuid", contentID: "chapter:13", sectionID: "section-uuid", chapterNumber: 1, titleRussian: nil, m770ID: "13", m770URL: "https://m770.org/rambam/13", sortOrder: 1, contentVersion: 1, isPublished: true, deletedAt: nil, updatedAt: "2026-09-04T10:00:00Z")],
            halakhot: [RemoteHalakhahDTO(id: "halakhah-uuid", contentID: "halakha:13:1:0", chapterID: "chapter-uuid", lawNumber: 1, partIndex: 0, textRussian: "Основа основ.", textHebrew: "יסוד היסודות.", notes: [], sortOrder: 1, contentVersion: 1, isPublished: true, deletedAt: nil, updatedAt: "2026-09-04T10:00:00Z")]
        )
    }
}

private final class MockRemoteContent: RemoteContentFetching {
    var fetchChangesCallCount = 0
    private let meta: RemoteContentMetaDTO
    private let changes: RemoteContentChanges
    private let error: Error?

    init(meta: RemoteContentMetaDTO = RemoteContentMetaDTO(contentVersion: 1, schemaVersion: 1, updatedAt: "2026-09-04T10:00:00Z"), changes: RemoteContentChanges = .empty, error: Error? = nil) {
        self.meta = meta
        self.changes = changes
        self.error = error
    }

    func fetchContentMeta() async throws -> RemoteContentMetaDTO {
        if let error { throw error }
        return meta
    }

    func fetchChanges(localVersion: Int, updatedAfter: String?) async throws -> RemoteContentChanges {
        fetchChangesCallCount += 1
        if let error { throw error }
        return changes
    }
}
