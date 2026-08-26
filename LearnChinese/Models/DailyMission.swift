//
//  DailyMission.swift
//  LearnChinese
//

import Foundation

struct HSKRange: Equatable, Sendable {
    static let levels = 1...6
    static let `default` = HSKRange(min: 1, max: 4)

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
}

struct DailyMission: Sendable, Decodable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    let situationChinese: String
    let situationPinyin: String
    let situationEnglish: String
    let taskChinese: String
    let taskPinyin: String
    let taskEnglish: String
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
