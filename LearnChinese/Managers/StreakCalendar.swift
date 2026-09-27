//
//  StreakCalendar.swift
//  LearnChinese
//

import Foundation

enum StreakCalendar {
    /// Days with no study stay faint. The busiest day in view is full strength.
    static let emptyOpacity = 0.18

    /// Maps a day's activity count onto dot strength.
    /// The highest count keeps full darkness (1). Fewer activities are lighter.
    static func opacity(count: Int, peak: Int) -> Double {
        guard count > 0 else { return emptyOpacity }
        let busiest = max(peak, count)
        if count >= busiest { return 1 }
        let fraction = Double(count) / Double(busiest)
        return emptyOpacity + (1 - emptyOpacity) * fraction
    }

    static func countsByDay(
        _ activities: [(dayStart: Date, count: Int)],
        calendar: Calendar
    ) -> [Date: Int] {
        var map: [Date: Int] = [:]
        for activity in activities {
            let day = calendar.startOfDay(for: activity.dayStart)
            map[day, default: 0] += max(0, activity.count)
        }
        return map
    }

    /// Consecutive active days through today, or through yesterday when today is still empty.
    static func currentStreak(
        dayCounts: [Date: Int],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var cursor = today
        if (dayCounts[today] ?? 0) <= 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while (dayCounts[cursor] ?? 0) > 0 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Calendar weeks ending in the week that contains `now`, aligned to `calendar.firstWeekday`.
    static func weeks(endingOn now: Date, weekCount: Int, calendar: Calendar) -> [Date] {
        guard weekCount > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let distance = (weekday - calendar.firstWeekday + 7) % 7
        guard let startOfWeek = calendar.date(byAdding: .day, value: -distance, to: today),
              let gridStart = calendar.date(byAdding: .day, value: -(weekCount - 1) * 7, to: startOfWeek)
        else { return [] }

        return (0..<(weekCount * 7)).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: gridStart).map { calendar.startOfDay(for: $0) }
        }
    }

    static func peak(
        in days: [Date],
        dayCounts: [Date: Int],
        through now: Date,
        calendar: Calendar
    ) -> Int {
        let end = calendar.startOfDay(for: now)
        return days
            .filter { $0 <= end }
            .map { dayCounts[$0] ?? 0 }
            .max() ?? 0
    }
}
