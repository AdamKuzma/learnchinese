//
//  LearnChineseTests.swift
//  LearnChineseTests
//

import Foundation
import SwiftData
import Testing
@testable import LearnChinese

struct HanziNormalizerTests {
    @Test func trimsAndComposes() {
        #expect(HanziNormalizer.normalize("  了\n") == "了")
        #expect(HanziNormalizer.normalize("了") == "了")
    }

    @Test func lookupKeysExpandOptionalParentheses() {
        let keys = HanziNormalizer.lookupKeys(for: "没（有）")
        #expect(keys.contains("没（有）"))
        #expect(keys.contains("没有"))
        #expect(keys.contains("没"))
    }
}

struct LearningStatusTests {
    @Test func neverAddedIsNotLearnedEvenWithCounters() {
        #expect(
            MasteryCriteria.status(
                hasFlashcard: false,
                lessonConfirmations: 10,
                dailyMissionCompletions: 2
            ) == .notLearned
        )
    }

    @Test func addedOnlyIsLearning() {
        #expect(
            MasteryCriteria.status(
                hasFlashcard: true,
                lessonConfirmations: 0,
                dailyMissionCompletions: 0
            ) == .learning
        )
    }

    @Test func tenQuizAndZeroMissionsIsLearning() {
        #expect(
            MasteryCriteria.status(
                hasFlashcard: true,
                lessonConfirmations: 10,
                dailyMissionCompletions: 0
            ) == .learning
        )
    }

    @Test func nineQuizAndTwoMissionsIsLearning() {
        #expect(
            MasteryCriteria.status(
                hasFlashcard: true,
                lessonConfirmations: 9,
                dailyMissionCompletions: 2
            ) == .learning
        )
    }

    @Test func tenQuizAndTwoMissionsIsMastered() {
        #expect(
            MasteryCriteria.status(
                hasFlashcard: true,
                lessonConfirmations: 10,
                dailyMissionCompletions: 2
            ) == .mastered
        )
    }
}

struct CatalogFixture {
    static let catalog = HSKCatalog(
        vocab: [
            HSKVocabWord(hanzi: "了", pinyin: "le", level: 1),
            HSKVocabWord(hanzi: "爱", pinyin: "ài", level: 1),
            HSKVocabWord(hanzi: "把", pinyin: "bǎ", level: 3),
            HSKVocabWord(hanzi: "没（有）", pinyin: "méi yǒu", level: 1)
        ],
        grammar: [
            HSKGrammarPoint(id: "hsk3-1-le", level: 1, pattern: "了", matchTokens: ["了"]),
            HSKGrammarPoint(id: "hsk3-1-de", level: 1, pattern: "的", matchTokens: ["的"]),
            HSKGrammarPoint(id: "hsk3-3-ba", level: 3, pattern: "把", matchTokens: ["把"])
        ]
    )
}

struct HSKCatalogTests {
    @Test func matchesOfficialHanziAndMissesCustomWords() {
        let catalog = CatalogFixture.catalog
        #expect(catalog.vocab(for: "了")?.level == 1)
        #expect(catalog.vocab(for: " 了 ")?.level == 1)
        #expect(catalog.vocab(for: "爱")?.level == 1)
        #expect(catalog.vocab(for: "把")?.level == 3)
        #expect(catalog.vocab(for: "蓝牙") == nil)
        #expect(catalog.isCustom(hanzi: "蓝牙"))
        #expect(!catalog.isCustom(hanzi: "了"))
    }

    @Test func matchesParentheticalVocabAliases() {
        let catalog = CatalogFixture.catalog
        #expect(catalog.vocab(for: "没（有）")?.hanzi == "没（有）")
        #expect(catalog.vocab(for: "没有")?.hanzi == "没（有）")
        #expect(catalog.vocab(for: "没")?.hanzi == "没（有）")
    }

    @Test func grammarPointsMatchParticleTokens() {
        let catalog = CatalogFixture.catalog
        let points = catalog.grammarPoints(for: "了")
        #expect(points.map(\.id) == ["hsk3-1-le"])
        #expect(catalog.grammarPoints(for: "蓝牙").isEmpty)
    }

    @Test func bundledCatalogRecognizesHSK1Particles() throws {
        let catalog = try #require(HSKCatalog.load(from: Bundle(for: ItemProgress.self)))
        #expect(catalog.vocab(for: "了")?.level == 1)
        #expect(catalog.vocab(for: "的")?.level == 1)
        #expect(!catalog.grammarPoints(for: "了").isEmpty)
        #expect(catalog.vocabTotal(level: 1) == 300)
        #expect(catalog.vocab(for: "把")?.level == 3)
        #expect((7...9).allSatisfy { catalog.vocabTotal(level: $0) == 0 })
        #expect(catalog.grammarTotal(level: 1) == 70)
    }
}

struct ProgressAggregationTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(UUID().uuidString, schema: Schema([Flashcard.self, ItemProgress.self]), isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema([Flashcard.self, ItemProgress.self]), configurations: configuration)
        return ModelContext(container)
    }

    @MainActor
    @Test func addingLeIncrementsVocabAndGrammarAtLevel1() throws {
        let context = try makeContext()
        let card = Flashcard(hanzi: "了", pinyin: "le", english: "completed action")
        context.insert(card)

        let snapshot = ProgressService.snapshot(
            cards: [card],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        let level1 = snapshot.levels.first { $0.level == 1 }
        #expect(level1?.vocabAdded == 1)
        #expect(level1?.vocabLearning == 1)
        #expect(level1?.vocabMastered == 0)
        #expect(level1?.grammarAdded == 1)
        #expect(level1?.grammarLearning == 1)
        #expect(snapshot.levels.first { $0.level == 3 }?.vocabAdded == 0)
        #expect(snapshot.custom.added == 0)
    }

    @MainActor
    @Test func customWordsDoNotCountTowardHSKTotals() throws {
        let context = try makeContext()
        let card = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")
        context.insert(card)

        let snapshot = ProgressService.snapshot(
            cards: [card],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.levels.allSatisfy { $0.vocabAdded == 0 && $0.grammarAdded == 0 })
        #expect(snapshot.custom.learning == 1)
        #expect(snapshot.custom.mastered == 0)
    }

    @MainActor
    @Test func wordCountsOnlyAtItsLowestLevel() throws {
        let context = try makeContext()
        let love = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let ba = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        context.insert(love)
        context.insert(ba)

        let snapshot = ProgressService.snapshot(
            cards: [love, ba],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.levels.first { $0.level == 1 }?.vocabAdded == 1)
        #expect(snapshot.levels.first { $0.level == 3 }?.vocabAdded == 1)
        #expect(snapshot.levels.filter { $0.level != 1 && $0.level != 3 }.allSatisfy { $0.vocabAdded == 0 })
    }

    @MainActor
    @Test func masteredRequiresBothThresholds() throws {
        let context = try makeContext()
        let card = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        context.insert(card)

        let almost = ItemProgress(
            normalizedHanzi: "爱",
            lessonConfirmations: 10,
            dailyMissionCompletions: 1
        )
        context.insert(almost)

        let learningSnapshot = ProgressService.snapshot(
            cards: [card],
            progress: [almost],
            catalog: CatalogFixture.catalog
        )
        #expect(learningSnapshot.levels.first { $0.level == 1 }?.vocabLearning == 1)
        #expect(learningSnapshot.levels.first { $0.level == 1 }?.vocabMastered == 0)

        almost.dailyMissionCompletions = 2
        let masteredSnapshot = ProgressService.snapshot(
            cards: [card],
            progress: [almost],
            catalog: CatalogFixture.catalog
        )
        #expect(masteredSnapshot.levels.first { $0.level == 1 }?.vocabLearning == 0)
        #expect(masteredSnapshot.levels.first { $0.level == 1 }?.vocabMastered == 1)
    }

    @MainActor
    @Test func deletingFlashcardReturnsNotLearnedWhileKeepingCounters() throws {
        let context = try makeContext()
        let progress = ItemProgress(
            normalizedHanzi: "爱",
            lessonConfirmations: 10,
            dailyMissionCompletions: 2
        )
        context.insert(progress)

        #expect(
            ProgressService.status(for: "爱", cards: [], progress: [progress]) == .notLearned
        )

        let card = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        context.insert(card)
        #expect(
            ProgressService.status(for: "爱", cards: [card], progress: [progress]) == .mastered
        )
    }

    @MainActor
    @Test func summaryUsesTheSelectedHSKRange() throws {
        let context = try makeContext()
        let love = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let ba = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        context.insert(love)
        context.insert(ba)

        let snapshot = ProgressService.snapshot(
            cards: [love, ba],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        let ranged = snapshot.summary(in: HSKRange(min: 1, max: 1))
        #expect(ranged.vocabAdded == 1)
        #expect(ranged.vocabTotal == 3)
        let wider = snapshot.summary(in: HSKRange(min: 1, max: 3))
        #expect(wider.vocabAdded == 2)
    }

    @MainActor
    @Test func lessonConfirmationIncrementsStoredProgress() throws {
        let context = try makeContext()
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordLessonConfirmation(hanzi: " 爱 ", in: context)
        let stored = ProgressService.progress(for: "爱", in: context)
        #expect(stored.lessonConfirmations == 2)
        #expect(stored.dailyMissionCompletions == 0)
    }
}
