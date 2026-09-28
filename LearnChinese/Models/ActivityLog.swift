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
    static func firstActivityDate(
        events: [ActivityEvent] = SharedStore.activityEvents
    ) -> Date? {
        events.map(\.date).min()
    }

    static func counts(
        lastDays: Int,
        ending now: Date = .now,
        calendar: Calendar = .current,
        events: [ActivityEvent] = SharedStore.activityEvents
    ) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(lastDays - 1), to: today) ?? today
        return counts(from: start, through: today, calendar: calendar, events: events)
    }

    static func countsFromFirstActivity(
        through now: Date = .now,
        calendar: Calendar = .current,
        events: [ActivityEvent] = SharedStore.activityEvents,
        emptyFallbackDays: Int = 30
    ) -> [DayCount] {
        guard let first = firstActivityDate(events: events) else {
            return counts(lastDays: emptyFallbackDays, ending: now, calendar: calendar, events: events)
        }
        return counts(from: first, through: now, calendar: calendar, events: events)
    }

    static func counts(
        from start: Date,
        through end: Date,
        calendar: Calendar = .current,
        events: [ActivityEvent] = SharedStore.activityEvents
    ) -> [DayCount] {
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard first <= last else { return [] }

        var buckets: [Date: Int] = [:]
        buckets.reserveCapacity(events.count)
        for event in events {
            let day = calendar.startOfDay(for: event.date)
            guard day >= first, day <= last else { continue }
            buckets[day, default: 0] += 1
        }

        let dayCount = (calendar.dateComponents([.day], from: first, to: last).day ?? 0) + 1
        return (0..<dayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return nil }
            return DayCount(date: day, count: buckets[day] ?? 0)
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
