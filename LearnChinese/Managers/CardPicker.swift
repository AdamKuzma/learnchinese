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
    var hasFlashcard: Bool = true
    var starCount: Int = 0
    var missionDayCount: Int = 0

    var needsStars: Bool {
        hasFlashcard && starCount < 3
    }

    var remainingMissionPractice: Int {
        VocabStars.remainingMissionPracticeToNextStar(
            starCount: starCount,
            missionCount: dailyMissionCompletions,
            missionDayCount: missionDayCount
        )
    }

    var status: LearningStatus {
        MasteryCriteria.status(
            hasFlashcard: hasFlashcard,
            lessonConfirmations: lessonConfirmations,
            dailyMissionCompletions: dailyMissionCompletions
        )
    }
}

enum CardPicker {
    static let cooldownInterval: TimeInterval = 4 * 60 * 60
    static let masteredPickChance = 0.12
    static let newItemPickChance = 0.78
    static let discoverNeedsStarsChance = 0.72
    static let deckNeedsStarsChance = 0.9
    static let vocabFocusChance = 0.84

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

    static func pickMissionTarget(
        level: Int,
        catalog: HSKCatalog = .bundled,
        cards: [Flashcard] = [],
        progress: [ItemProgress] = [],
        source: MissionVocabSource = .discoverHSK,
        lastKey: String? = nil,
        lastKeys: Set<String> = [],
        now: Date = .now
    ) -> DailyMissionTargetWord? {
        var rng = SystemRandomNumberGenerator()
        return pickMissionTarget(
            level: level,
            catalog: catalog,
            cards: cards,
            progress: progress,
            source: source,
            lastKey: lastKey,
            lastKeys: lastKeys,
            now: now,
            rng: &rng
        )
    }

    static func pickMissionTarget<R: RandomNumberGenerator>(
        level: Int,
        catalog: HSKCatalog = .bundled,
        cards: [Flashcard] = [],
        progress: [ItemProgress] = [],
        source: MissionVocabSource = .discoverHSK,
        lastKey: String? = nil,
        lastKeys: Set<String> = [],
        now: Date = .now,
        rng: inout R
    ) -> DailyMissionTargetWord? {
        let pools = missionPools(
            level: level,
            catalog: catalog,
            cards: cards,
            progress: progress,
            source: source
        )
        let excluded = excludedKeys(lastKey: lastKey, lastKeys: lastKeys)
        let focus: MissionFocus
        if pools.vocab.candidates.isEmpty, pools.grammar.candidates.isEmpty {
            return nil
        } else if pools.vocab.candidates.isEmpty {
            focus = .grammar
        } else if pools.grammar.candidates.isEmpty || source.prefersSavedVocabulary {
            focus = .vocabulary
        } else if Double.random(in: 0..<1, using: &rng) < vocabFocusChance {
            focus = .vocabulary
        } else {
            focus = .grammar
        }
        return pickFromPool(
            focus == .grammar ? pools.grammar : pools.vocab,
            source: source,
            isVocabulary: focus == .vocabulary,
            excluding: excluded,
            now: now,
            rng: &rng
        )
    }

    static func pickDualMissionTargets(
        level: Int,
        catalog: HSKCatalog = .bundled,
        cards: [Flashcard] = [],
        progress: [ItemProgress] = [],
        source: MissionVocabSource = .discoverHSK,
        lastKeys: Set<String> = [],
        now: Date = .now
    ) -> (vocabulary: DailyMissionTargetWord, grammar: DailyMissionTargetWord)? {
        var rng = SystemRandomNumberGenerator()
        return pickDualMissionTargets(
            level: level,
            catalog: catalog,
            cards: cards,
            progress: progress,
            source: source,
            lastKeys: lastKeys,
            now: now,
            rng: &rng
        )
    }

    static func pickDualMissionTargets<R: RandomNumberGenerator>(
        level: Int,
        catalog: HSKCatalog = .bundled,
        cards: [Flashcard] = [],
        progress: [ItemProgress] = [],
        source: MissionVocabSource = .discoverHSK,
        lastKeys: Set<String> = [],
        now: Date = .now,
        rng: inout R
    ) -> (vocabulary: DailyMissionTargetWord, grammar: DailyMissionTargetWord)? {
        let pools = missionPools(
            level: level,
            catalog: catalog,
            cards: cards,
            progress: progress,
            source: source
        )
        guard let vocabulary = pickFromPool(
            pools.vocab,
            source: source,
            isVocabulary: true,
            excluding: lastKeys,
            now: now,
            rng: &rng
        ) else {
            return nil
        }
        var grammarExcluded = lastKeys
        grammarExcluded.insert(HanziNormalizer.normalize(vocabulary.hanzi))
        guard let grammar = pickFromPool(
            pools.grammar,
            source: source,
            isVocabulary: false,
            excluding: grammarExcluded,
            now: now,
            rng: &rng
        ),
              HanziNormalizer.normalize(grammar.hanzi) != HanziNormalizer.normalize(vocabulary.hanzi)
        else {
            return nil
        }
        return (vocabulary, grammar)
    }

    static func pickCandidate<R: RandomNumberGenerator>(
        from candidates: [CardPickCandidate],
        sessionKeys: Set<String> = [],
        lastKey: String? = nil,
        lastKeys: Set<String> = [],
        now: Date = .now,
        rng: inout R
    ) -> CardPickCandidate? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        let excluded = excludedKeys(lastKey: lastKey, lastKeys: lastKeys)
        let withoutLast = excluded.isEmpty ? candidates : candidates.filter { !excluded.contains($0.key) }
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

        let notLearned = candidates.filter { $0.status == .notLearned }
        let learning = candidates.filter { $0.status == .learning }
        let mastered = candidates.filter { $0.status == .mastered }

        let group: [CardPickCandidate]
        if !notLearned.isEmpty {
            let onlyNew = learning.isEmpty && mastered.isEmpty
            if onlyNew || Double.random(in: 0..<1, using: &rng) < newItemPickChance {
                group = notLearned
            } else if learning.isEmpty {
                group = mastered
            } else if mastered.isEmpty {
                group = learning
            } else if Double.random(in: 0..<1, using: &rng) < masteredPickChance {
                group = mastered
            } else {
                group = learning
            }
        } else if learning.isEmpty {
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

    private static func makeCandidate(
        key: String,
        savedKeys: Set<String>,
        progress: [ItemProgress]
    ) -> CardPickCandidate {
        let record = progressRecord(for: key, in: progress)
        return CardPickCandidate(
            key: key,
            lessonConfirmations: record?.lessonConfirmations ?? 0,
            dailyMissionCompletions: record?.dailyMissionCompletions ?? 0,
            lastShownAt: record?.lastShownAt,
            hasFlashcard: HanziNormalizer.lookupKeys(for: key).contains(where: { savedKeys.contains($0) }),
            starCount: VocabStars.count(for: record),
            missionDayCount: record?.missionDayKeys.count ?? 0
        )
    }

    private static func savedLookupKeys(from cards: [Flashcard], kind: FlashcardKind) -> Set<String> {
        var keys = Set<String>()
        for card in cards where card.cardKind == kind {
            for key in HanziNormalizer.lookupKeys(for: card.hanzi) {
                keys.insert(key)
            }
        }
        return keys
    }

    private static func flashcardField(
        _ keyPath: KeyPath<Flashcard, String>,
        for hanzi: String,
        kind: FlashcardKind,
        cards: [Flashcard]
    ) -> String {
        let keys = Set(HanziNormalizer.lookupKeys(for: hanzi))
        guard let card = cards.first(where: { card in
            card.cardKind == kind && keys.contains(HanziNormalizer.normalize(card.hanzi))
        }) else {
            return ""
        }
        return card[keyPath: keyPath]
    }

    private struct MissionTargetPool {
        var candidates: [CardPickCandidate]
        var targets: [String: DailyMissionTargetWord]
    }

    private static func missionPools(
        level: Int,
        catalog: HSKCatalog,
        cards: [Flashcard],
        progress: [ItemProgress],
        source: MissionVocabSource
    ) -> (vocab: MissionTargetPool, grammar: MissionTargetPool) {
        let hskLevel = min(max(level, HSKRange.levels.lowerBound), HSKRange.levels.upperBound)
        let vocabSaved = savedLookupKeys(from: cards, kind: .vocabulary)
        let grammarSaved = savedLookupKeys(from: cards, kind: .grammar)
        let catalogVocab = catalogVocabPool(
            level: hskLevel,
            catalog: catalog,
            cards: cards,
            progress: progress,
            savedKeys: vocabSaved
        )
        let vocab: MissionTargetPool
        if source == .practiceDeck {
            let deck = savedVocabPool(cards: cards, progress: progress, savedKeys: vocabSaved)
            vocab = deck.candidates.isEmpty ? catalogVocab : deck
        } else {
            vocab = catalogVocab
        }

        var grammarTargets: [String: DailyMissionTargetWord] = [:]
        var grammarCandidates: [CardPickCandidate] = []
        for point in catalog.grammar(level: hskLevel) {
            for phrase in point.missionTargetPhrases {
                guard grammarTargets[phrase] == nil else { continue }
                grammarTargets[phrase] = DailyMissionTargetWord(
                    hanzi: phrase,
                    pinyin: flashcardField(\.pinyin, for: phrase, kind: .grammar, cards: cards),
                    meaning: flashcardField(\.displayEnglish, for: phrase, kind: .grammar, cards: cards),
                    focus: .grammar
                )
                grammarCandidates.append(makeCandidate(key: phrase, savedKeys: grammarSaved, progress: progress))
            }
        }

        return (
            vocab,
            MissionTargetPool(candidates: grammarCandidates, targets: grammarTargets)
        )
    }

    private static func catalogVocabPool(
        level: Int,
        catalog: HSKCatalog,
        cards: [Flashcard],
        progress: [ItemProgress],
        savedKeys: Set<String>
    ) -> MissionTargetPool {
        var targets: [String: DailyMissionTargetWord] = [:]
        var candidates: [CardPickCandidate] = []
        for word in catalog.vocab(level: level) {
            let key = HanziNormalizer.normalize(word.hanzi)
            guard !key.isEmpty, targets[key] == nil else { continue }
            targets[key] = DailyMissionTargetWord(
                hanzi: word.hanzi,
                pinyin: word.pinyin,
                meaning: flashcardField(\.displayEnglish, for: key, kind: .vocabulary, cards: cards),
                focus: .vocabulary
            )
            candidates.append(makeCandidate(key: key, savedKeys: savedKeys, progress: progress))
        }
        return MissionTargetPool(candidates: candidates, targets: targets)
    }

    private static func savedVocabPool(
        cards: [Flashcard],
        progress: [ItemProgress],
        savedKeys: Set<String>
    ) -> MissionTargetPool {
        var targets: [String: DailyMissionTargetWord] = [:]
        var candidates: [CardPickCandidate] = []
        for card in cards where card.cardKind == .vocabulary {
            let key = HanziNormalizer.normalize(card.hanzi)
            guard !key.isEmpty, targets[key] == nil else { continue }
            targets[key] = DailyMissionTargetWord(card: card)
            candidates.append(makeCandidate(key: key, savedKeys: savedKeys, progress: progress))
        }
        return MissionTargetPool(candidates: candidates, targets: targets)
    }

    private static func pickFromPool<R: RandomNumberGenerator>(
        _ pool: MissionTargetPool,
        source: MissionVocabSource,
        isVocabulary: Bool,
        excluding lastKeys: Set<String>,
        now: Date,
        rng: inout R
    ) -> DailyMissionTargetWord? {
        guard let picked = pickMissionCandidate(
            from: pool.candidates,
            source: source,
            isVocabulary: isVocabulary,
            lastKeys: lastKeys,
            now: now,
            rng: &rng
        ) else {
            return nil
        }
        return pool.targets[picked.key]
    }

    static func pickMissionCandidate<R: RandomNumberGenerator>(
        from candidates: [CardPickCandidate],
        source: MissionVocabSource,
        isVocabulary: Bool,
        lastKeys: Set<String>,
        now: Date = .now,
        rng: inout R
    ) -> CardPickCandidate? {
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        let withoutLast = lastKeys.isEmpty ? candidates : candidates.filter { !lastKeys.contains($0.key) }
        let pool = withoutLast.isEmpty ? candidates : withoutLast
        let fresh = pool.filter { candidate in
            !isCoolingDown(lastShownAt: candidate.lastShownAt, now: now)
        }
        let active = fresh.isEmpty ? pool : fresh
        if isVocabulary {
            return pickVocabForStars(from: active, source: source, rng: &rng)
        }
        return weightedPick(from: active, rng: &rng)
    }

    private static func pickVocabForStars<R: RandomNumberGenerator>(
        from candidates: [CardPickCandidate],
        source: MissionVocabSource,
        rng: inout R
    ) -> CardPickCandidate? {
        let needsStars = candidates.filter(\.needsStars)
        let chance = source == .practiceDeck ? deckNeedsStarsChance : discoverNeedsStarsChance

        if source == .practiceDeck {
            let deck = candidates.filter(\.hasFlashcard)
            let group: [CardPickCandidate]
            if !needsStars.isEmpty, deck.count == needsStars.count || Double.random(in: 0..<1, using: &rng) < chance {
                group = needsStars
            } else {
                group = deck.isEmpty ? candidates : deck
            }
            return sample(group.map { ($0, nextStarWeight($0)) }, rng: &rng)
        }

        if !needsStars.isEmpty, Double.random(in: 0..<1, using: &rng) < chance {
            return sample(needsStars.map { ($0, nextStarWeight($0)) }, rng: &rng)
        }
        return weightedPick(from: candidates, rng: &rng)
    }

    private static func nextStarWeight(_ candidate: CardPickCandidate) -> Double {
        VocabStars.missionPickWeight(
            remainingPractice: candidate.remainingMissionPractice,
            starCount: candidate.starCount
        )
    }

    private static func excludedKeys(lastKey: String?, lastKeys: Set<String>) -> Set<String> {
        var excluded = lastKeys
        if let lastKey, !lastKey.isEmpty {
            excluded.insert(lastKey)
        }
        return excluded
    }
}
