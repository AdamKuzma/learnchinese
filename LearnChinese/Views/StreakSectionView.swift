//
//  StreakSectionView.swift
//  LearnChinese
//

import SwiftData
import SwiftUI

struct StreakSectionView: View {
    let activities: [DailyActivity]
    var now: Date = .now
    var calendar: Calendar = .current

    private let weekCount = 5

    var body: some View {
        let counts = StreakCalendar.countsByDay(
            activities.map { ($0.dayStart, $0.count) },
            calendar: calendar
        )
        let days = StreakCalendar.weeks(endingOn: now, weekCount: weekCount, calendar: calendar)
        let peak = StreakCalendar.peak(in: days, dayCounts: counts, through: now, calendar: calendar)
        let streak = StreakCalendar.currentStreak(dayCounts: counts, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(streakTitle(streak))
                    .font(.headline)
                Spacer()
                Text(todayTitle(counts[today] ?? 0))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }

                ForEach(days, id: \.self) { day in
                    dot(for: day, count: counts[day] ?? 0, peak: peak, today: today)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        guard symbols.count == 7, start >= 0, start < symbols.count else { return symbols }
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private func dot(for day: Date, count: Int, peak: Int, today: Date) -> some View {
        let isFuture = day > today
        let fill: Color = isFuture
            ? .clear
            : .primary.opacity(StreakCalendar.opacity(count: count, peak: peak))

        return Circle()
            .fill(fill)
            .frame(width: 16, height: 16)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(dotLabel(day: day, count: count, isFuture: isFuture))
            .accessibilityHidden(isFuture)
    }

    private func streakTitle(_ streak: Int) -> String {
        switch streak {
        case 0: return "No streak yet"
        case 1: return "1 day streak"
        default: return "\(streak) day streak"
        }
    }

    private func todayTitle(_ count: Int) -> String {
        switch count {
        case 0: return "0 today"
        case 1: return "1 today"
        default: return "\(count) today"
        }
    }

    private func dotLabel(day: Date, count: Int, isFuture: Bool) -> String {
        let date = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        if isFuture { return date }
        if count == 1 { return "\(date), 1 activity" }
        return "\(date), \(count) activities"
    }
}
