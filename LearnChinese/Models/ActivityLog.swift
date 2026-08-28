//
//  ActivityLog.swift
//  LearnChinese
//

import Foundation

enum ActivityKind: String, Codable, Sendable {
    case lesson
    case dailyMission
}

struct ActivityEvent: Codable, Hashable, Sendable {
    var date: Date
    var kind: ActivityKind
}

struct DayCount: Identifiable, Sendable {
    var date: Date
    var count: Int
    var id: Date { date }
}

enum ActivityHistory {
    static func counts(lastDays: Int, ending now: Date = .now, calendar: Calendar = .current) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        let events = SharedStore.activityEvents
        return (0..<lastDays).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let count = events.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return DayCount(date: day, count: count)
        }
    }

    static func completedDays(calendar: Calendar = .current) -> Set<Date> {
        completedDaySet(calendar: calendar)
    }

    static func currentStreak(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let days = completedDaySet(calendar: calendar)
        guard !days.isEmpty else { return 0 }

        var cursor = days.contains(today) ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        if !days.contains(cursor) { return 0 }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func longestStreak(calendar: Calendar = .current) -> Int {
        let days = completedDaySet(calendar: calendar).sorted()
        guard let first = days.first else { return 0 }

        var longest = 1
        var current = 1
        var previous = first

        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if gap == 1 {
                current += 1
                longest = max(longest, current)
            } else if gap > 1 {
                current = 1
            }
            previous = day
        }

        return longest
    }

    private static func completedDaySet(calendar: Calendar) -> Set<Date> {
        Set(SharedStore.activityEvents.map { calendar.startOfDay(for: $0.date) })
    }
}
