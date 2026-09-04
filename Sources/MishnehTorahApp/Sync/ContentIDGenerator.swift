import Foundation

enum ContentIDGenerator {
    static func bookID(order: Int) -> String {
        "book:\(order)"
    }

    static func sectionID(bookOrder: Int, sectionOrder: Int) -> String {
        "section:\(bookOrder):\(sectionOrder)"
    }

    static func chapterID(m770ID: String) -> String {
        "chapter:\(m770ID)"
    }

    static func halakhahID(m770ID: String, lawNumber: Int, partIndex: Int) -> String {
        "halakha:\(m770ID):\(lawNumber):\(partIndex)"
    }
}
