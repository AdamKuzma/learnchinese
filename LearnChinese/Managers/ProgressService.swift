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
    static func recordLessonConfirmation(
        hanzi: String,
        in context: ModelContext,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.lessonConfirmations += 1
        recordSuccessfulActivity(on: record, kind: .recall, at: date, calendar: calendar)
        recordActivity(on: date, in: context, calendar: calendar)
        try? context.save()
        return record
    }

    @discardableResult
    static func recordLessonMiss(
        hanzi: String,
        in context: ModelContext
    ) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.lessonConfirmations = max(0, record.lessonConfirmations - 1)
        try? context.save()
        return record
    }

    @discardableResult
    static func recordMissionCompletion(
        hanzi: String,
        in context: ModelContext,
        at date: Date = .now,
        calendar: Calendar = .current
    ) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.dailyMissionCompletions += 1
        recordSuccessfulActivity(on: record, kind: .mission, at: date, calendar: calendar)
        recordActivity(on: date, in: context, calendar: calendar)
        try? context.save()
        return record
    }

    @discardableResult
    static func markShown(hanzi: String, in context: ModelContext, at date: Date = .now) -> ItemProgress {
        let record = progress(for: hanzi, in: context)
        record.lastShownAt = date
        try? context.save()
        return record
    }

    static func recordActivity(
        on date: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: date)
        let existing = (try? context.fetch(FetchDescriptor<DailyActivity>())) ?? []
        if let match = existing.first(where: { calendar.isDate($0.dayStart, inSameDayAs: start) }) {
            match.count += 1
        } else {
            context.insert(DailyActivity(dayStart: start, count: 1))
        }
    }

    static func snapshot(
        cards: [Flashcard],
        progress: [ItemProgress],
        catalog: HSKCatalog = .bundled
    ) -> HSKProgressSnapshot {
        let vocabCards = cards.filter { $0.cardKind == .vocabulary }
        let addedKeys = Set(vocabCards.map { HanziNormalizer.normalize($0.hanzi) }.filter { !$0.isEmpty })
        let progressByKey = Dictionary(uniqueKeysWithValues: progress.map { ($0.normalizedHanzi, $0) })

        var cumulativeLearning = 0
        var cumulativeMastered = 0
        var cumulativeCatalog = 0
        let levels = HSKRange.levels.map { level -> HSKLevelProgress in
            let vocabWords = catalog.vocab(level: level)
            var vocabLearning = 0
            var vocabMastered = 0
            for word in vocabWords {
                switch cardStatus(for: word.hanzi, addedKeys: addedKeys, progressByKey: progressByKey) {
                case .learning: vocabLearning += 1
                case .mastered: vocabMastered += 1
                case .notLearned: break
                }
            }
            cumulativeLearning += vocabLearning
            cumulativeMastered += vocabMastered
            cumulativeCatalog += vocabWords.count
            let learned = cumulativeLearning + cumulativeMastered
            let published = catalog.publishedCumulativeTotals[level] ?? cumulativeCatalog
            return HSKLevelProgress(
                level: level,
                vocabTotal: max(published, learned),
                vocabLearning: cumulativeLearning,
                vocabMastered: cumulativeMastered
            )
        }

        return HSKProgressSnapshot(levels: Array(levels))
    }

    static func progress(
        for level: Int,
        cards: [Flashcard],
        progress: [ItemProgress],
        catalog: HSKCatalog = .bundled
    ) -> HSKLevelProgress {
        let clamped = min(max(level, HSKRange.levels.lowerBound), HSKRange.levels.upperBound)
        let vocabCards = cards.filter { $0.cardKind == .vocabulary }
        let addedKeys = Set(vocabCards.map { HanziNormalizer.normalize($0.hanzi) }.filter { !$0.isEmpty })
        let progressByKey = Dictionary(uniqueKeysWithValues: progress.map { ($0.normalizedHanzi, $0) })

        var vocabLearning = 0
        var vocabMastered = 0
        var catalogCount = 0
        for candidate in HSKRange.levels where candidate <= clamped {
            let vocabWords = catalog.vocab(level: candidate)
            catalogCount += vocabWords.count
            for word in vocabWords {
                switch cardStatus(for: word.hanzi, addedKeys: addedKeys, progressByKey: progressByKey) {
                case .learning: vocabLearning += 1
                case .mastered: vocabMastered += 1
                case .notLearned: break
                }
            }
        }

        let learned = vocabLearning + vocabMastered
        let published = catalog.publishedCumulativeTotals[clamped] ?? catalogCount
        return HSKLevelProgress(
            level: clamped,
            vocabTotal: max(published, learned),
            vocabLearning: vocabLearning,
            vocabMastered: vocabMastered
        )
    }

    static func learningDeckTargets(
        cards: [Flashcard],
        progress: [ItemProgress],
        range: HSKRange,
        catalog: HSKCatalog = .bundled
    ) -> [Flashcard] {
        cards.filter { card in
            guard card.cardKind == .vocabulary else { return false }
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

    private enum StarActivityKind {
        case recall
        case mission
    }

    private static func recordSuccessfulActivity(
        on record: ItemProgress,
        kind: StarActivityKind,
        at date: Date,
        calendar: Calendar
    ) {
        let key = DayKeyStore.key(for: date, calendar: calendar)
        switch kind {
        case .recall:
            var days = record.recallDayKeys
            days.insert(key)
            record.recallDayKeys = days
        case .mission:
            var days = record.missionDayKeys
            days.insert(key)
            record.missionDayKeys = days
        }

        if let first = record.firstActivityAt {
            record.firstActivityAt = min(first, date)
        } else {
            record.firstActivityAt = date
        }
        if let last = record.lastActivityAt {
            record.lastActivityAt = max(last, date)
        } else {
            record.lastActivityAt = date
        }
    }
}
