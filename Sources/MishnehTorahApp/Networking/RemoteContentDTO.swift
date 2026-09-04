import Foundation

struct RemoteContentMetaDTO: Decodable, Equatable {
    let contentVersion: Int
    let schemaVersion: Int
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case contentVersion = "content_version"
        case schemaVersion = "schema_version"
        case updatedAt = "updated_at"
    }
}

struct RemoteBookDTO: Decodable, Equatable {
    let id: String
    let contentID: String
    let titleRussian: String
    let titleHebrew: String
    let sortOrder: Int
    let contentVersion: Int
    let isPublished: Bool
    let deletedAt: String?
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case contentID = "content_id"
        case titleRussian = "title_ru"
        case titleHebrew = "title_he"
        case sortOrder = "sort_order"
        case contentVersion = "content_version"
        case isPublished = "is_published"
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteSectionDTO: Decodable, Equatable {
    let id: String
    let contentID: String
    let bookID: String
    let titleRussian: String
    let titleHebrew: String
    let sortOrder: Int
    let contentVersion: Int
    let isPublished: Bool
    let deletedAt: String?
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case contentID = "content_id"
        case bookID = "book_id"
        case titleRussian = "title_ru"
        case titleHebrew = "title_he"
        case sortOrder = "sort_order"
        case contentVersion = "content_version"
        case isPublished = "is_published"
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteChapterDTO: Decodable, Equatable {
    let id: String
    let contentID: String
    let sectionID: String
    let chapterNumber: Int
    let titleRussian: String?
    let m770ID: String?
    let m770URL: String?
    let sortOrder: Int
    let contentVersion: Int
    let isPublished: Bool
    let deletedAt: String?
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case contentID = "content_id"
        case sectionID = "section_id"
        case chapterNumber = "chapter_number"
        case titleRussian = "title_ru"
        case m770ID = "m770_id"
        case m770URL = "m770_url"
        case sortOrder = "sort_order"
        case contentVersion = "content_version"
        case isPublished = "is_published"
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteHalakhahDTO: Decodable, Equatable {
    let id: String
    let contentID: String
    let chapterID: String
    let lawNumber: Int
    let partIndex: Int
    let textRussian: String
    let textHebrew: String
    let notes: [String]
    let sortOrder: Int
    let contentVersion: Int
    let isPublished: Bool
    let deletedAt: String?
    let updatedAt: String

    private enum CodingKeys: String, CodingKey {
        case id
        case contentID = "content_id"
        case chapterID = "chapter_id"
        case lawNumber = "law_number"
        case partIndex = "part_index"
        case textRussian = "text_ru"
        case textHebrew = "text_he"
        case notes
        case sortOrder = "sort_order"
        case contentVersion = "content_version"
        case isPublished = "is_published"
        case deletedAt = "deleted_at"
        case updatedAt = "updated_at"
    }
}

struct RemoteContentChanges: Equatable {
    var books: [RemoteBookDTO]
    var sections: [RemoteSectionDTO]
    var chapters: [RemoteChapterDTO]
    var halakhot: [RemoteHalakhahDTO]

    static let empty = RemoteContentChanges(books: [], sections: [], chapters: [], halakhot: [])
}
