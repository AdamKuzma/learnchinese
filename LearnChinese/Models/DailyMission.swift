//
//  DailyMission.swift
//  LearnChinese
//

import Foundation

enum MissionDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy
    case medium
    case hard
    case extreme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }

    var promptGuidance: String {
        switch self {
        case .easy:
            return """
            Make a simple, immediately understandable situation with one clear beat.
            Situation: one short sentence.
            Task: one short spoken reply the learner would actually say.
            No twists, complaints, competing options, or extra constraints.
            """
        case .medium:
            return """
            Make a realistic situation with a little extra context, such as a preference, a small constraint, or a follow-up.
            Situation: one sentence with a specific detail.
            Task: one complete reply that includes a reason or a little extra information.
            Keep it straightforward; no high-stakes conflict.
            """
        case .hard:
            return """
            Make a layered situation: a goal plus an obstacle, competing needs, or social nuance.
            Situation: one or two sentences with a specific complication.
            Task: a fuller reply of about two sentences that explains, persuades, compares, or handles the complication.
            """
        case .extreme:
            return """
            Make a memorable, high-pressure, or socially complex situation that still feels plausible.
            Include multiple moving parts: new information, a constraint, and a person to manage.
            Situation: two sentences with a twist.
            Task: a complete response of two or three sentences that handles the issue, states a decision, and gives a reason.
            """
        }
    }
}

enum MissionTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case everydayLife
    case travel
    case social
    case problemSolving
    case decisionMaking
    case conflict
    case unexpected
    case awkwardFunny

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everydayLife: return "Everyday life"
        case .travel: return "Travel"
        case .social: return "Social"
        case .problemSolving: return "Problem solving"
        case .decisionMaking: return "Decision making"
        case .conflict: return "Conflict"
        case .unexpected: return "Unexpected situations"
        case .awkwardFunny: return "Awkward / funny"
        }
    }

    var promptGuidance: String {
        switch self {
        case .everydayLife:
            return "Normal situations like shopping, commuting, restaurants, or appointments."
        case .travel:
            return """
            Common travel situations on a trip: airport check-in or security, asking for a gate or platform, hotels and check-in/out, taxis or ride-hailing, buying tickets, asking for directions, customs, lost luggage, or finding a bathroom, SIM card, or restaurant nearby.
            Keep it a real traveler-to-staff or traveler-to-local exchange, not a vacation recap.
            """
        case .social:
            return "Friends, coworkers, meeting people, or invitations."
        case .problemSolving:
            return "Something goes wrong and the learner needs to handle it."
        case .decisionMaking:
            return "Compare options, make a choice, and explain why."
        case .conflict:
            return "Disagreement, complaint, misunderstanding, or negotiation."
        case .unexpected:
            return "Plans change or new information appears."
        case .awkwardFunny:
            return "Socially uncomfortable or memorable situations."
        }
    }
}

enum MissionFocus: String, CaseIterable, Codable, Sendable {
    case vocabulary
    case grammar

    var sectionTitle: String {
        switch self {
        case .vocabulary: return "Target word"
        case .grammar: return "Target grammar"
        }
    }

    var usedCorrectlyLabel: String {
        switch self {
        case .vocabulary: return "Target word used correctly"
        case .grammar: return "Target grammar used correctly"
        }
    }
}

struct HSKRange: Equatable, Sendable {
    static let levels = 1...6
    static let defaultLevel = 3
    static let `default` = HSKRange(min: defaultLevel, max: defaultLevel)

    var min: Int
    var max: Int

    var title: String { "HSK \(min)–\(max)" }

    init(min: Int, max: Int) {
        let clampedMin = min.clamped(to: Self.levels)
        let clampedMax = max.clamped(to: Self.levels)
        self.min = Swift.min(clampedMin, clampedMax)
        self.max = Swift.max(clampedMin, clampedMax)
    }

    func updatingMin(_ newMin: Int) -> HSKRange {
        let clamped = newMin.clamped(to: Self.levels)
        return HSKRange(min: clamped, max: Swift.max(clamped, max))
    }

    func updatingMax(_ newMax: Int) -> HSKRange {
        let clamped = newMax.clamped(to: Self.levels)
        return HSKRange(min: Swift.min(min, clamped), max: clamped)
    }

    func contains(_ level: Int) -> Bool {
        (min...max).contains(level)
    }
}

struct DailyMissionTargetWord: Sendable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    let focus: MissionFocus

    init(hanzi: String, pinyin: String, meaning: String, focus: MissionFocus) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        self.focus = focus
    }

    init(card: Flashcard) {
        self.init(
            hanzi: card.hanzi,
            pinyin: card.pinyin,
            meaning: card.displayEnglish,
            focus: card.cardKind == .grammar ? .grammar : .vocabulary
        )
    }
}

struct MissionWord: Sendable, Codable, Hashable {
    var hanzi: String
    var pinyin: String
    var english: String

    var isTappable: Bool {
        hanzi.contains { $0.isCJK }
    }

    var hasDetails: Bool {
        !pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(hanzi: String, pinyin: String, english: String) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
    }

    enum CodingKeys: String, CodingKey {
        case hanzi, pinyin, english
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hanzi = try container.decode(String.self, forKey: .hanzi)
        pinyin = try container.decodeIfPresent(String.self, forKey: .pinyin) ?? ""
        english = try container.decodeIfPresent(String.self, forKey: .english) ?? ""
    }
}

struct DailyMission: Sendable, Decodable {
    var focus: MissionFocus
    var hanzi: String
    var pinyin: String
    var meaning: String
    let situationChinese: String
    let situationPinyin: String
    let situationEnglish: String
    let taskChinese: String
    let taskPinyin: String
    let taskEnglish: String
    let situationWords: [MissionWord]
    let taskWords: [MissionWord]

    var situationTokens: [MissionWord] {
        ChineseWordSegmenter.resolvedWords(sentence: situationChinese, provided: situationWords)
    }

    var taskTokens: [MissionWord] {
        ChineseWordSegmenter.resolvedWords(sentence: taskChinese, provided: taskWords)
    }

    enum CodingKeys: String, CodingKey {
        case focus, hanzi, pinyin, meaning
        case situationChinese, situationPinyin, situationEnglish, situationWords
        case taskChinese, taskPinyin, taskEnglish, taskWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try? container.decodeIfPresent(String.self, forKey: .focus),
           let decoded = MissionFocus(rawValue: raw) {
            focus = decoded
        } else {
            focus = .vocabulary
        }
        hanzi = try container.decode(String.self, forKey: .hanzi)
        pinyin = container.decodeFlexibleString(.pinyin)
        meaning = container.decodeFlexibleString(.meaning)
        situationChinese = container.decodeFlexibleString(.situationChinese)
        situationPinyin = container.decodeFlexibleString(.situationPinyin)
        situationEnglish = container.decodeFlexibleString(.situationEnglish)
        taskChinese = container.decodeFlexibleString(.taskChinese)
        taskPinyin = container.decodeFlexibleString(.taskPinyin)
        taskEnglish = container.decodeFlexibleString(.taskEnglish)
        situationWords = (try? container.decode([MissionWord].self, forKey: .situationWords)) ?? []
        taskWords = (try? container.decode([MissionWord].self, forKey: .taskWords)) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        return ""
    }
}

struct DailyMissionEvaluation: Sendable {
    let success: Bool
    let meaning: Int
    let grammar: Int
    let naturalness: Int
    let targetWordUsedCorrectly: Bool
    let feedback: String
    let naturalChinese: String
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
