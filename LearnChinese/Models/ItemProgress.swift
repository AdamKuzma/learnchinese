//
//  ItemProgress.swift
//  LearnChinese
//

import Foundation
import SwiftData

@Model
final class ItemProgress {
    @Attribute(.unique) var normalizedHanzi: String
    var lessonConfirmations: Int
    var dailyMissionCompletions: Int
    var lastShownAt: Date?
    var recallDaysJSON: String = "[]"
    var missionDaysJSON: String = "[]"
    var firstActivityAt: Date?
    var lastActivityAt: Date?

    init(
        normalizedHanzi: String,
        lessonConfirmations: Int = 0,
        dailyMissionCompletions: Int = 0,
        lastShownAt: Date? = nil,
        recallDaysJSON: String = "[]",
        missionDaysJSON: String = "[]",
        firstActivityAt: Date? = nil,
        lastActivityAt: Date? = nil
    ) {
        self.normalizedHanzi = HanziNormalizer.normalize(normalizedHanzi)
        self.lessonConfirmations = lessonConfirmations
        self.dailyMissionCompletions = dailyMissionCompletions
        self.lastShownAt = lastShownAt
        self.recallDaysJSON = recallDaysJSON
        self.missionDaysJSON = missionDaysJSON
        self.firstActivityAt = firstActivityAt
        self.lastActivityAt = lastActivityAt
    }

    var recallDayKeys: Set<String> {
        get { DayKeyStore.decode(recallDaysJSON) }
        set { recallDaysJSON = DayKeyStore.encode(newValue) }
    }

    var missionDayKeys: Set<String> {
        get { DayKeyStore.decode(missionDaysJSON) }
        set { missionDaysJSON = DayKeyStore.encode(newValue) }
    }
}

enum DayKeyStore {
    static func decode(_ json: String) -> Set<String> {
        guard let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data)
        else {
            return []
        }
        return Set(values.filter { !$0.isEmpty })
    }

    static func encode(_ days: Set<String>) -> String {
        let values = days.filter { !$0.isEmpty }.sorted()
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return json
    }

    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func spanDays(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        return calendar.dateComponents([.day], from: first, to: last).day ?? 0
    }
}
