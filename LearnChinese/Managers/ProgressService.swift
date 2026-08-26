//
//  ProgressService.swift
//  LearnChinese
//

import Foundation
import SwiftData

enum ProgressService {
    static func status(
        hasFlashcard: Bool,
        lessonConfirmations: Int,
        dailyMissionCompletions: Int
    ) -> LearningStatus {
        MasteryCriteria.status(
            hasFlashcard: hasFlashcard,
            lessonConfirmations: lessonConfirmations,
            dailyMissionCompletions: dailyMissionCompletions
        )
    }

    static func status(
        for hanzi: String,
        cards: [Flashcard],
        progress: [ItemProgress]
    ) -> LearningStatus {
        let key = HanziNormalizer.normalize(hanzi)
        let hasFlashcard = cards.contains { HanziNormalizer.normalize($0.hanzi) == key }
        let record = progressRecord(for: key, in: progress)
        return status(
            hasFlashcard: hasFlashcard,
            lessonConfirmations: record?.lessonConfirmations ?? 0,
            dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
        )
    }

    @discardableResult
    static func recordLessonConfirmation(hanzi: String, in context: ModelContext) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.lessonConfirmations += 1
        try? context.save()
        return record
    }

    @discardableResult
    static func recordMissionCompletion(hanzi: String, in context: ModelContext) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.dailyMissionCompletions += 1
        try? context.save()
        return record
    }

    static func snapshot(
        cards: [Flashcard],
        progress: [ItemProgress],
        catalog: HSKCatalog = .bundled
    ) -> HSKProgressSnapshot {
        let addedKeys = Set(cards.map { HanziNormalizer.normalize($0.hanzi) }.filter { !$0.isEmpty })
        let progressByKey = Dictionary(uniqueKeysWithValues: progress.map { ($0.normalizedHanzi, $0) })

        func cardStatus(for hanzi: String) -> LearningStatus {
            let keys = Set(HanziNormalizer.lookupKeys(for: hanzi))
            let hasCard = addedKeys.contains(where: { keys.contains($0) })
                || keys.contains(where: { addedKeys.contains($0) })
            let record = keys.compactMap { progressByKey[$0] }.first
            return status(
                hasFlashcard: hasCard,
                lessonConfirmations: record?.lessonConfirmations ?? 0,
                dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
            )
        }

        let levels = HSKRange.levels.map { level -> HSKLevelProgress in
            let vocabWords = catalog.vocab(level: level)
            var vocabLearning = 0
            var vocabMastered = 0
            for word in vocabWords {
                switch cardStatus(for: word.hanzi) {
                case .learning: vocabLearning += 1
                case .mastered: vocabMastered += 1
                case .notLearned: break
                }
            }

            let grammarPoints = catalog.grammar(level: level)
            var grammarLearning = 0
            var grammarMastered = 0
            for point in grammarPoints {
                switch grammarStatus(point, addedKeys: addedKeys, progressByKey: progressByKey) {
                case .learning: grammarLearning += 1
                case .mastered: grammarMastered += 1
                case .notLearned: break
                }
            }

            return HSKLevelProgress(
                level: level,
                vocabTotal: vocabWords.count,
                vocabLearning: vocabLearning,
                vocabMastered: vocabMastered,
                grammarTotal: grammarPoints.count,
                grammarLearning: grammarLearning,
                grammarMastered: grammarMastered
            )
        }

        var customLearning = 0
        var customMastered = 0
        for card in cards where catalog.isCustom(hanzi: card.hanzi) {
            switch cardStatus(for: card.hanzi) {
            case .learning: customLearning += 1
            case .mastered: customMastered += 1
            case .notLearned: break
            }
        }

        return HSKProgressSnapshot(
            levels: levels,
            custom: CustomProgress(learning: customLearning, mastered: customMastered)
        )
    }

    static func trackedItems(
        level: Int?,
        customOnly: Bool = false,
        cards: [Flashcard],
        progress: [ItemProgress],
        catalog: HSKCatalog = .bundled
    ) -> [TrackedItem] {
        let addedKeys = Set(cards.map { HanziNormalizer.normalize($0.hanzi) }.filter { !$0.isEmpty })
        let progressByKey = Dictionary(uniqueKeysWithValues: progress.map { ($0.normalizedHanzi, $0) })
        let cardsByKey = Dictionary(
            cards.map { (HanziNormalizer.normalize($0.hanzi), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        if customOnly {
            return cards.compactMap { card -> TrackedItem? in
                guard catalog.isCustom(hanzi: card.hanzi) else { return nil }
                return trackedFlashcard(card, progressByKey: progressByKey, kind: .custom, level: nil)
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }

        guard let level else { return [] }
        var items: [TrackedItem] = []

        for word in catalog.vocab(level: level) {
            let itemStatus = cardStatus(
                for: word.hanzi,
                addedKeys: addedKeys,
                progressByKey: progressByKey
            )
            guard itemStatus != .notLearned else { continue }
            let record = progressRecord(for: word.hanzi, in: progress)
            let card = matchingCard(for: word.hanzi, cardsByKey: cardsByKey)
            items.append(
                TrackedItem(
                    id: "vocab-\(word.hanzi)",
                    title: word.hanzi,
                    subtitle: card?.pinyin.isEmpty == false ? (card?.pinyin ?? word.pinyin) : word.pinyin,
                    kind: .vocab,
                    level: level,
                    status: itemStatus,
                    lessonConfirmations: record?.lessonConfirmations ?? 0,
                    dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
                )
            )
        }

        for point in catalog.grammar(level: level) {
            let itemStatus = grammarStatus(point, addedKeys: addedKeys, progressByKey: progressByKey)
            guard itemStatus != .notLearned else { continue }
            let record = bestProgress(for: point, progressByKey: progressByKey)
            items.append(
                TrackedItem(
                    id: "grammar-\(point.id)",
                    title: point.pattern.isEmpty ? point.id : point.pattern,
                    subtitle: "Grammar",
                    kind: .grammar,
                    level: level,
                    status: itemStatus,
                    lessonConfirmations: record?.lessonConfirmations ?? 0,
                    dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
                )
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.status != rhs.status {
                return lhs.status == .mastered && rhs.status == .learning
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    static func learningDeckTargets(
        cards: [Flashcard],
        progress: [ItemProgress],
        range: HSKRange,
        catalog: HSKCatalog = .bundled
    ) -> [Flashcard] {
        cards.filter { card in
            guard let level = catalog.vocab(for: card.hanzi)?.level, range.contains(level) else {
                return false
            }
            return status(for: card.hanzi, cards: cards, progress: progress) == .learning
        }
    }

    static func progress(for hanzi: String, in context: ModelContext) -> ItemProgress {
        let key = HanziNormalizer.normalize(hanzi)
        var descriptor = FetchDescriptor<ItemProgress>(
            predicate: #Predicate { $0.normalizedHanzi == key }
        )
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = ItemProgress(normalizedHanzi: key)
        context.insert(created)
        return created
    }

    private static func progressRecord(for hanzi: String, in progress: [ItemProgress]) -> ItemProgress? {
        let keys = Set(HanziNormalizer.lookupKeys(for: hanzi))
        return progress.first { keys.contains($0.normalizedHanzi) }
    }

    private static func cardStatus(
        for hanzi: String,
        addedKeys: Set<String>,
        progressByKey: [String: ItemProgress]
    ) -> LearningStatus {
        let keys = Set(HanziNormalizer.lookupKeys(for: hanzi))
        let hasCard = addedKeys.contains(where: { keys.contains($0) })
        let record = keys.compactMap { progressByKey[$0] }.first
        return status(
            hasFlashcard: hasCard,
            lessonConfirmations: record?.lessonConfirmations ?? 0,
            dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
        )
    }

    private static func grammarStatus(
        _ point: HSKGrammarPoint,
        addedKeys: Set<String>,
        progressByKey: [String: ItemProgress]
    ) -> LearningStatus {
        let tokens = grammarTokens(point)
        var sawLearning = false
        var sawMastered = false
        for token in tokens {
            switch cardStatus(for: token, addedKeys: addedKeys, progressByKey: progressByKey) {
            case .mastered: sawMastered = true
            case .learning: sawLearning = true
            case .notLearned: break
            }
        }
        if sawMastered { return .mastered }
        if sawLearning { return .learning }
        return .notLearned
    }

    private static func grammarTokens(_ point: HSKGrammarPoint) -> [String] {
        var tokens = point.matchTokens.map(HanziNormalizer.normalize)
        let pattern = HanziNormalizer.normalize(point.pattern)
        if !pattern.isEmpty { tokens.append(pattern) }
        return tokens.filter { !$0.isEmpty }
    }

    private static func bestProgress(
        for point: HSKGrammarPoint,
        progressByKey: [String: ItemProgress]
    ) -> ItemProgress? {
        grammarTokens(point)
            .flatMap { HanziNormalizer.lookupKeys(for: $0) }
            .compactMap { progressByKey[$0] }
            .max {
                ($0.lessonConfirmations + $0.dailyMissionCompletions * 100)
                    < ($1.lessonConfirmations + $1.dailyMissionCompletions * 100)
            }
    }

    private static func matchingCard(for hanzi: String, cardsByKey: [String: Flashcard]) -> Flashcard? {
        for key in HanziNormalizer.lookupKeys(for: hanzi) {
            if let card = cardsByKey[key] {
                return card
            }
        }
        return nil
    }

    private static func trackedFlashcard(
        _ card: Flashcard,
        progressByKey: [String: ItemProgress],
        kind: TrackedItemKind,
        level: Int?
    ) -> TrackedItem {
        let key = HanziNormalizer.normalize(card.hanzi)
        let record = progressByKey[key]
        return TrackedItem(
            id: "custom-\(key)",
            title: card.hanzi,
            subtitle: card.pinyin,
            kind: kind,
            level: level,
            status: status(
                hasFlashcard: true,
                lessonConfirmations: record?.lessonConfirmations ?? 0,
                dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
            ),
            lessonConfirmations: record?.lessonConfirmations ?? 0,
            dailyMissionCompletions: record?.dailyMissionCompletions ?? 0
        )
    }
}
