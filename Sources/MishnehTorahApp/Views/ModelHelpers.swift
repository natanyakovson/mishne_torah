import Foundation

extension MTBook {
    var sortedSections: [MTSection] {
        sections.sorted { $0.order < $1.order }
    }
}

extension MTSection {
    var sortedChapters: [MTChapter] {
        chapters.sorted { $0.number < $1.number }
    }
}

extension MTChapter {
    var sortedHalakhot: [MTHalakhah] {
        halakhot.sorted { $0.number < $1.number }
    }
}

extension MTHalakhah {
    var notes: [String] {
        guard let notesJSON,
              let data = notesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    var reference: String {
        let chapterText = chapter.map { "гл. \($0.number)" } ?? "гл. ?"
        let sectionText = chapter?.section?.titleRussian ?? "Раздел"
        let bookText = chapter?.section?.book?.titleRussian ?? "Книга"
        return "\(bookText), \(sectionText), \(chapterText), закон \(number)"
    }

    var russianDisplayText: String {
        russianText ?? "Русский текст для этого закона ещё не импортирован."
    }

    var hebrewDisplayText: String {
        hebrewText.isEmpty ? "Иврит для этого закона не найден в источнике." : hebrewText
    }

    var searchPreviewText: String {
        if let russianText, !russianText.isEmpty {
            return russianText
        }
        return hebrewText
    }

    var searchableText: String {
        ([hebrewText, russianText ?? "", reference] + notes).joined(separator: " ")
    }
}
