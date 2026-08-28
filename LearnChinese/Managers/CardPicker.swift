//
//  CardPicker.swift
//  LearnChinese
//

import Foundation
import SwiftData

struct CardPickCandidate: Equatable, Sendable {
    var key: String
    var lessonConfirmations: Int
    var dailyMissionCompletions: Int
    var lastShownAt: Date?

    var status: LearningStatus {
        MasteryCriteria.status(
            hasFlashcard: true,
            lessonConfirmations: lessonConfirmations,
            dailyMissionCompletions: dailyMissionCompletions
        )
    }
}

enum CardPicker {
    static let cooldownInterval: TimeInterval = 4 * 60 * 60
    static let masteredPickChance = 0.12

    static func pick(
        from cards: [Flashcard],
        progress: [ItemProgress],
        sessionKeys: Set<String> = [],
        lastKey: String? = nil,
        now: Date = .now
    ) -> Flashcard? {
        var rng = SystemRandomNumberGenerator()
        return pick(
            from: cards,
            progress: progress,
            sessionKeys: sessionKeys,
            lastKey: lastKey,
            now: now,
            rng: &rng
        )
    }

    static func pick<R: RandomNumberGenerator>(
        from cards: [Flashcard],
        progress: [ItemProgress],
        sessionKeys: Set<String> = [],
        lastKey: String? = nil,
        now: Date = .now,
        rng: inout R
    ) -> Flashcard? {
        var cardsByKey: [String: Flashcard] = [:]
        var candidates: [CardPickCandidate] = []
        candidates.reserveCapacity(cards.count)

        for card in cards {
            let key = HanziNormalizer.normalize(card.hanzi)
            guard !key.isEmpty, cardsByKey[key] == nil else { continue }
            cardsByKey[key] = card
            let record = progressRecord(for: key, in: progress)
            candidates.append(
                CardPickCandidate(
                    key: key,
                    lessonConfirmations: record?.lessonConfirmations ?? 0,
                    dailyMissionCompletions: record?.dailyMissionCompletions ?? 0,
                    lastShownAt: record?.lastShownAt
                )
            )
        }

        guard let picked = pickCandidate(
            from: candidates,
            sessionKeys: sessionKeys,
            lastKey: lastKey,
            now: now,
            rng: &rng
        ) else {
            return nil
        }
        return cardsByKey[picked.key]
    }

    static func pickCandidate<R: RandomNumberGenerator>(
        from candidates: [CardPickCandidate],
        sessionKeys: Set<String> = [],
        lastKey: String? = nil,
        now: Date = .now,
        rng: inout R
    ) -> CardPickCandidate? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        let withoutLast = lastKey.map { key in candidates.filter { $0.key != key } } ?? candidates
        let pool = withoutLast.isEmpty ? candidates : withoutLast

        let fresh = pool.filter { candidate in
            !sessionKeys.contains(candidate.key) && !isCoolingDown(lastShownAt: candidate.lastShownAt, now: now)
        }
        let active = fresh.isEmpty ? pool : fresh
        return weightedPick(from: active, rng: &rng)
    }

    static func isCoolingDown(lastShownAt: Date?, now: Date) -> Bool {
        guard let lastShownAt else { return false }
        return now.timeIntervalSince(lastShownAt) < cooldownInterval
    }

    static func learningWeight(lessonConfirmations: Int) -> Double {
        max(3, 10 - Double(max(0, lessonConfirmations)) * 0.7)
    }

    private static func weightedPick<R: RandomNumberGenerator>(
        from candidates: [CardPickCandidate],
        rng: inout R
    ) -> CardPickCandidate? {
        guard !candidates.isEmpty else { return nil }

        let learning = candidates.filter { $0.status == .learning }
        let mastered = candidates.filter { $0.status == .mastered }

        let group: [CardPickCandidate]
        if learning.isEmpty {
            group = mastered.isEmpty ? candidates : mastered
        } else if mastered.isEmpty {
            group = learning
        } else if Double.random(in: 0..<1, using: &rng) < masteredPickChance {
            group = mastered
        } else {
            group = learning
        }

        let weighted = group.map { candidate in
            let weight = candidate.status == .mastered
                ? 1.0
                : learningWeight(lessonConfirmations: candidate.lessonConfirmations)
            return (candidate, weight)
        }
        return sample(weighted, rng: &rng)
    }

    private static func sample<T, R: RandomNumberGenerator>(
        _ items: [(T, Double)],
        rng: inout R
    ) -> T? {
        let total = items.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return items.last?.0 }
        var cursor = Double.random(in: 0..<total, using: &rng)
        for (item, weight) in items {
            cursor -= weight
            if cursor <= 0 { return item }
        }
        return items.last?.0
    }

    private static func progressRecord(for hanzi: String, in progress: [ItemProgress]) -> ItemProgress? {
        let keys = Set(HanziNormalizer.lookupKeys(for: hanzi))
        return progress.first { keys.contains($0.normalizedHanzi) }
    }
}
