import Foundation

enum TextSearchNormalizer {
    static func normalized(_ text: String) -> String {
        let folded = text
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
        var scalars = String.UnicodeScalarView()

        for scalar in folded.unicodeScalars where !isIgnoredSearchScalar(scalar) {
            scalars.append(scalar)
        }

        return String(scalars)
    }

    static func contains(_ text: String, query: String) -> Bool {
        let needle = normalized(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return normalized(text).contains(needle)
    }

    static func ranges(in text: String, matching query: String) -> [Range<String.Index>] {
        let needle = Array(normalized(query).trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return [] }

        let haystack = normalizedCharactersWithSourceRanges(for: text)
        guard haystack.characters.count >= needle.count else { return [] }

        var ranges: [Range<String.Index>] = []
        var start = 0
        while start <= haystack.characters.count - needle.count {
            let end = start + needle.count
            if Array(haystack.characters[start..<end]) == needle {
                ranges.append(haystack.sourceRanges[start].lowerBound..<haystack.sourceRanges[end - 1].upperBound)
                start = end
            } else {
                start += 1
            }
        }
        return ranges
    }

    private static func normalizedCharactersWithSourceRanges(for text: String) -> (characters: [Character], sourceRanges: [Range<String.Index>]) {
        var characters: [Character] = []
        var sourceRanges: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            let sourceRange = index..<nextIndex
            let folded = String(text[sourceRange])
                .precomposedStringWithCanonicalMapping
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))

            for scalar in folded.unicodeScalars where !isIgnoredSearchScalar(scalar) {
                characters.append(Character(String(scalar)))
                sourceRanges.append(sourceRange)
            }

            index = nextIndex
        }

        return (characters, sourceRanges)
    }

    private static func isIgnoredSearchScalar(_ scalar: UnicodeScalar) -> Bool {
        scalar.properties.isDiacritic || (0x0591...0x05C7).contains(Int(scalar.value))
    }
}

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
