//
//  SharedStore.swift
//  LearnChinese
//
//  Lightweight wrapper around the App Group UserDefaults that both the main app
//  and the DeviceActivityMonitor extension read from / write to.
//

import Foundation
import FamilyControls

enum SessionMode: String, CaseIterable, Codable, Identifiable {
    case quick
    case standard
    case deep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .deep: return "Deep"
        }
    }

    var requiredCorrect: Int {
        switch self {
        case .quick: return 10
        case .standard: return 30
        case .deep: return 60
        }
    }

    var unlockDuration: TimeInterval {
        switch self {
        case .quick: return 5 * 60
        case .standard: return 15 * 60
        case .deep: return 30 * 60
        }
    }

    var summary: String {
        "\(requiredCorrect) cards \u{2192} \(unlockMinutes) min"
    }

    var unlockMinutes: Int {
        Int(unlockDuration / 60)
    }
}

enum QuestionTypeMode: String, CaseIterable, Codable, Identifiable {
    case chineseToEnglish
    case englishToChinese
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chineseToEnglish: return "Chinese to English"
        case .englishToChinese: return "English to Chinese"
        case .mixed: return "Mixed"
        }
    }
}

enum Energy {
    static let capMinutes = 30
    static let dailyMissionReward = 15
}

enum SharedStore {
    static let appGroup = "group.adamkuzma.LearnChinese"
    static let managedSettingsStoreName = "LearnChineseShield"
    static let deviceActivityName = "LearnChineseUnlock"
    static let dailyDeviceActivityName = "LearnChineseDaily"
    static let unlockThresholdEventName = "LearnChineseUnlockThreshold"

    private enum Key {
        static let selection = "blockedSelection"
        static let blockingEnabled = "blockingEnabled"
        static let unlockUntil = "unlockUntil"
        static let sessionMode = "sessionMode"
        static let questionTypeMode = "questionTypeMode"
        static let hskRangeMin = "hskRangeMin"
        static let hskRangeMax = "hskRangeMax"
        static let hskLevel = "hskLevel"
        static let missionDifficulty = "missionDifficulty"
        static let missionVocabSource = "missionVocabSource"
        static let missionThemes = "missionThemes"
        static let energyDayStart = "energyDayStart"
        static let activityEvents = "activityEvents"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    // MARK: - Blocked app selection

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: Key.selection)
    }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults?.data(forKey: Key.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            return FamilyActivitySelection()
        }
        return selection
    }

    // MARK: - Blocking enabled flag

    static var blockingEnabled: Bool {
        get { defaults?.bool(forKey: Key.blockingEnabled) ?? false }
        set { defaults?.set(newValue, forKey: Key.blockingEnabled) }
    }

    // MARK: - Unlock window

    /// The moment the temporary unlock expires, if one is active.
    static var unlockUntil: Date? {
        get {
            let value = defaults?.double(forKey: Key.unlockUntil) ?? 0
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        set {
            if let newValue {
                defaults?.set(newValue.timeIntervalSince1970, forKey: Key.unlockUntil)
            } else {
                defaults?.removeObject(forKey: Key.unlockUntil)
            }
        }
    }

    // MARK: - Session mode

    static var sessionMode: SessionMode {
        get {
            guard let raw = defaults?.string(forKey: Key.sessionMode),
                  let mode = SessionMode(rawValue: raw)
            else {
                return .standard
            }
            return mode
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Key.sessionMode)
        }
    }

    static var questionTypeMode: QuestionTypeMode {
        get {
            guard let raw = defaults?.string(forKey: Key.questionTypeMode),
                  let mode = QuestionTypeMode(rawValue: raw)
            else {
                return .chineseToEnglish
            }
            return mode
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Key.questionTypeMode)
        }
    }

    // MARK: - Daily Mission HSK range

    // MARK: - Daily Mission HSK level

    static var hskLevel: Int {
        get {
            if defaults?.object(forKey: Key.hskLevel) != nil {
                return clampedLevel(defaults?.integer(forKey: Key.hskLevel) ?? HSKRange.defaultLevel)
            }
            return hskRange.max
        }
        set {
            let level = clampedLevel(newValue)
            defaults?.set(level, forKey: Key.hskLevel)
            hskRange = HSKRange(min: level, max: level)
        }
    }

    static var hskRange: HSKRange {
        get {
            let hasMin = defaults?.object(forKey: Key.hskRangeMin) != nil
            let hasMax = defaults?.object(forKey: Key.hskRangeMax) != nil
            guard hasMin || hasMax else {
                return HSKRange(min: HSKRange.defaultLevel, max: HSKRange.defaultLevel)
            }
            return HSKRange(
                min: hasMin ? (defaults?.integer(forKey: Key.hskRangeMin) ?? HSKRange.defaultLevel) : HSKRange.defaultLevel,
                max: hasMax ? (defaults?.integer(forKey: Key.hskRangeMax) ?? HSKRange.defaultLevel) : HSKRange.defaultLevel
            )
        }
        set {
            defaults?.set(newValue.min, forKey: Key.hskRangeMin)
            defaults?.set(newValue.max, forKey: Key.hskRangeMax)
        }
    }

    private static func clampedLevel(_ level: Int) -> Int {
        min(max(level, HSKRange.levels.lowerBound), HSKRange.levels.upperBound)
    }

    // MARK: - Daily Mission difficulty and themes

    static var missionDifficulty: MissionDifficulty {
        get {
            guard let raw = defaults?.string(forKey: Key.missionDifficulty),
                  let difficulty = MissionDifficulty(rawValue: raw)
            else {
                return .medium
            }
            return difficulty
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Key.missionDifficulty)
        }
    }

    static var missionVocabSource: MissionVocabSource {
        get {
            guard let raw = defaults?.string(forKey: Key.missionVocabSource),
                  let source = MissionVocabSource(rawValue: raw)
            else {
                return .discoverHSK
            }
            return source
        }
        set {
            defaults?.set(newValue.rawValue, forKey: Key.missionVocabSource)
        }
    }

    static var missionThemes: Set<MissionTheme> {
        get {
            let raw = defaults?.stringArray(forKey: Key.missionThemes) ?? []
            let themes = Set(raw.compactMap(MissionTheme.init(rawValue:)))
            return themes.isEmpty ? Set(MissionTheme.allCases) : themes
        }
        set {
            let themes = newValue.isEmpty ? Set(MissionTheme.allCases) : newValue
            defaults?.set(
                MissionTheme.allCases.filter(themes.contains).map(\.rawValue),
                forKey: Key.missionThemes
            )
        }
    }

    // MARK: - Energy day

    /// Start of the calendar day energy was last refreshed. Used to reset at midnight.
    static var energyDayStart: Date? {
        get {
            let value = defaults?.double(forKey: Key.energyDayStart) ?? 0
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        set {
            if let newValue {
                defaults?.set(newValue.timeIntervalSince1970, forKey: Key.energyDayStart)
            } else {
                defaults?.removeObject(forKey: Key.energyDayStart)
            }
        }
    }

    // MARK: - Activity history

    static var activityEvents: [ActivityEvent] {
        get {
            guard let data = defaults?.data(forKey: Key.activityEvents),
                  let events = try? JSONDecoder().decode([ActivityEvent].self, from: data)
            else {
                return []
            }
            return events
        }
        set {
            defaults?.set(try? JSONEncoder().encode(newValue), forKey: Key.activityEvents)
        }
    }

    static func recordActivity(_ kind: ActivityKind) {
        var events = activityEvents
        events.append(ActivityEvent(date: .now, kind: kind))
        activityEvents = events
    }

    // MARK: - Profile photo

    static var profilePhotoData: Data? {
        get {
            guard let url = profilePhotoURL else { return nil }
            return try? Data(contentsOf: url)
        }
        set {
            guard let url = profilePhotoURL else { return }
            if let newValue {
                try? newValue.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static var profilePhotoURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("profilePhoto.jpg")
    }
}
