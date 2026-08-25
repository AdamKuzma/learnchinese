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

    private enum Key {
        static let selection = "blockedSelection"
        static let blockingEnabled = "blockingEnabled"
        static let unlockUntil = "unlockUntil"
        static let sessionMode = "sessionMode"
        static let questionTypeMode = "questionTypeMode"
        static let hskRangeMin = "hskRangeMin"
        static let hskRangeMax = "hskRangeMax"
        static let energyDayStart = "energyDayStart"
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

    static var hskRange: HSKRange {
        get {
            let hasMin = defaults?.object(forKey: Key.hskRangeMin) != nil
            let hasMax = defaults?.object(forKey: Key.hskRangeMax) != nil
            guard hasMin || hasMax else {
                return .default
            }
            return HSKRange(
                min: hasMin ? (defaults?.integer(forKey: Key.hskRangeMin) ?? HSKRange.default.min) : HSKRange.default.min,
                max: hasMax ? (defaults?.integer(forKey: Key.hskRangeMax) ?? HSKRange.default.max) : HSKRange.default.max
            )
        }
        set {
            defaults?.set(newValue.min, forKey: Key.hskRangeMin)
            defaults?.set(newValue.max, forKey: Key.hskRangeMax)
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
}
