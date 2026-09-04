import Foundation

struct DailyRambamReading {
    let cycle: ReadingCycle
    let chapters: [MTChapter]

    var title: String {
        cycle.shortTitle
    }
}

enum ReadingCycleSchedule {
    static func reading(for cycle: ReadingCycle, books: [MTBook], date: Date = .now, calendar: Calendar = .current) -> DailyRambamReading? {
        guard cycle != .none else { return nil }
        var calculationCalendar = Calendar(identifier: .gregorian)
        calculationCalendar.timeZone = calendar.timeZone

        let chapters = books
            .sorted { $0.order < $1.order }
            .flatMap(\.sortedSections)
            .flatMap(\.sortedChapters)

        guard !chapters.isEmpty else { return nil }

        let today = calculationCalendar.startOfDay(for: date)
        let firstChapterDate = calculationCalendar.startOfDay(for: startDate(for: cycle, calendar: calculationCalendar))
        guard let daysSinceStart = calculationCalendar.dateComponents([.day], from: firstChapterDate, to: today).day,
              daysSinceStart >= 0 else {
            return nil
        }

        let chapterStartIndex: Int
        switch cycle {
        case .none:
            return nil
        case .oneChapter:
            chapterStartIndex = daysSinceStart + oneChapterCorrection(for: today, calendar: calculationCalendar)
        case .threeChapters:
            chapterStartIndex = daysSinceStart * cycle.chaptersPerDay + threeChapterCorrection(for: today, calendar: calculationCalendar)
        }

        let normalizedStartIndex = positiveModulo(chapterStartIndex, chapters.count)
        let selectedChapters = (0..<cycle.chaptersPerDay).map { offset in
            chapters[(normalizedStartIndex + offset) % chapters.count]
        }

        return DailyRambamReading(cycle: cycle, chapters: selectedChapters)
    }

    private static func startDate(for cycle: ReadingCycle, calendar: Calendar) -> Date {
        switch cycle {
        case .none:
            return Date()
        case .oneChapter:
            return makeDate(year: 2026, month: 2, day: 15, calendar: calendar)
        case .threeChapters:
            return makeDate(year: 2026, month: 2, day: 7, calendar: calendar)
        }
    }

    private static func oneChapterCorrection(for date: Date, calendar: Calendar) -> Int {
        date >= makeDate(year: 2026, month: 7, day: 18, calendar: calendar) ? -1 : 0
    }

    private static func threeChapterCorrection(for date: Date, calendar: Calendar) -> Int {
        date >= makeDate(year: 2026, month: 3, day: 10, calendar: calendar) ? -1 : 0
    }

    private static func makeDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private static func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        ((value % modulus) + modulus) % modulus
    }
}
