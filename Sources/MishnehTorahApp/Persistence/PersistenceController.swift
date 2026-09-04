import Foundation
import SwiftData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    init(inMemory: Bool = false) throws {
        let schema = PersistenceController.schema
        let configuration = ModelConfiguration("MishnehTorahLocalStore", schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    private init() {
        do {
            self = try PersistenceController(inMemory: false)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    static var schema: Schema {
        Schema([
            MTBook.self,
            MTSection.self,
            MTChapter.self,
            MTHalakhah.self,
            MTBookmark.self,
            MTReadingHistory.self,
            MTTextHighlight.self,
            MTReaderSettings.self
        ])
    }
}
