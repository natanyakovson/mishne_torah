import Foundation
import SwiftData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([
            MTBook.self,
            MTSection.self,
            MTChapter.self,
            MTHalakhah.self,
            MTBookmark.self,
            MTReadingHistory.self,
            MTReaderSettings.self
        ])

        let configuration = ModelConfiguration("MishnehTorahLocalStore", schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            try SeedDataLoader.seedIfNeeded(context: ModelContext(container))
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }
}
