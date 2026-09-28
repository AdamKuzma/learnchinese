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
            HSKGrammarPoint(id: "hsk3-3-ba", level: 3, pattern: "把", matchTokens: ["把"]),
            HSKGrammarPoint(id: "hsk3-2-lai", level: 2, pattern: "来不及", matchTokens: ["来不及"])
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

    @Test func preferredSavedKindKeepsSharedVocabWordsOnVocabulary() {
        let catalog = CatalogFixture.catalog
        #expect(catalog.preferredSavedKind(for: "了") == .vocabulary)
        #expect(catalog.preferredSavedKind(for: "把") == .vocabulary)
        #expect(catalog.preferredSavedKind(for: "来不及") == .grammar)
        #expect(catalog.preferredSavedKind(for: "爱") == .vocabulary)
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
        #expect(catalog.preferredSavedKind(for: "了") == .vocabulary)
        #expect(catalog.preferredSavedKind(for: "越来越") == .grammar)
    }

    @Test func bundledProgressUsesPublishedCumulativeTotals() throws {
        let catalog = try #require(HSKCatalog.load(from: Bundle(for: ItemProgress.self)))
        let snapshot = ProgressService.snapshot(cards: [], progress: [], catalog: catalog)
        #expect(snapshot.progress(for: 1)?.vocabTotal == 300)
        #expect(snapshot.progress(for: 2)?.vocabTotal == 500)
        #expect(snapshot.progress(for: 3)?.vocabTotal == 1_000)
        #expect(snapshot.progress(for: 4)?.vocabTotal == 2_000)
        #expect(snapshot.progress(for: 5)?.vocabTotal == 3_600)
        #expect(snapshot.progress(for: 6)?.vocabTotal == 5_400)
        #expect(snapshot.progress(for: 2)?.vocabNew == 500)
        #expect(snapshot.progress(for: 3)?.vocabNew == 1_000)
        #expect(snapshot.progress(for: 4)?.vocabNew == 2_000)
    }
}

struct ProgressAggregationTests {
    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Flashcard.self, ItemProgress.self, DailyActivity.self])
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }

    @MainActor
    @Test func addingLeIncrementsVocabAtLevel1() throws {
        let card = Flashcard(hanzi: "了", pinyin: "le", english: "completed action")
        let snapshot = ProgressService.snapshot(
            cards: [card],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        let level1 = snapshot.progress(for: 1)
        #expect(level1?.vocabLearning == 1)
        #expect(level1?.vocabMastered == 0)
        #expect(level1?.vocabNew == 2)
        #expect(snapshot.progress(for: 3)?.vocabLearning == 1)
    }

    @MainActor
    @Test func restoreSavedKindsMovesGrammarOnlyCards() throws {
        let context = try makeContext()
        let vocab = Flashcard(hanzi: "了", pinyin: "le", english: "completed action")
        let grammar = Flashcard(hanzi: "来不及", pinyin: "láibují", english: "there's not enough time")
        context.insert(vocab)
        context.insert(grammar)
        try context.save()

        Flashcard.restoreSavedKinds(in: context, catalog: CatalogFixture.catalog)

        #expect(vocab.cardKind == .vocabulary)
        #expect(grammar.cardKind == .grammar)
    }

    @MainActor
    @Test func restoreSavedKindsMovesUsedDefinitionsToGrammar() throws {
        let context = try makeContext()
        let grammar = Flashcard(
            hanzi: "了",
            pinyin: "le",
            english: "Used to express a completed action"
        )
        let vocab = Flashcard(hanzi: "爱", pinyin: "ài", english: "to love")
        context.insert(grammar)
        context.insert(vocab)
        try context.save()

        Flashcard.restoreSavedKinds(in: context, catalog: CatalogFixture.catalog)

        #expect(grammar.cardKind == .grammar)
        #expect(vocab.cardKind == .vocabulary)
        #expect(Flashcard.looksLikeGrammarDefinition("Used after a verb to show change"))
        #expect(!Flashcard.looksLikeGrammarDefinition("Used"))
        #expect(!Flashcard.looksLikeGrammarDefinition("completed action"))
    }

    @MainActor
    @Test func grammarCardsDoNotCountTowardVocabProgress() throws {
        let card = Flashcard(hanzi: "了", pinyin: "le", english: "completed action", kind: .grammar)
        let snapshot = ProgressService.snapshot(
            cards: [card],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.progress(for: 1)?.vocabLearning == 0)
        #expect(snapshot.progress(for: 1)?.vocabNew == 3)
    }

    @MainActor
    @Test func customWordsDoNotCountTowardHSKTotals() throws {
        let card = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")
        let snapshot = ProgressService.snapshot(
            cards: [card],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.levels.allSatisfy { $0.vocabLearning == 0 && $0.vocabMastered == 0 })
    }

    @MainActor
    @Test func wordCountsOnlyAtItsLowestLevel() throws {
        let love = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let ba = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let snapshot = ProgressService.snapshot(
            cards: [love, ba],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.progress(for: 1)?.vocabLearning == 1)
        #expect(snapshot.progress(for: 2)?.vocabLearning == 1)
        #expect(snapshot.progress(for: 3)?.vocabLearning == 2)
        #expect(snapshot.progress(for: 4)?.vocabLearning == 2)
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
        #expect(learningSnapshot.progress(for: 1)?.vocabLearning == 1)
        #expect(learningSnapshot.progress(for: 1)?.vocabMastered == 0)

        almost.dailyMissionCompletions = 2
        let masteredSnapshot = ProgressService.snapshot(
            cards: [card],
            progress: [almost],
            catalog: CatalogFixture.catalog
        )
        #expect(masteredSnapshot.progress(for: 1)?.vocabLearning == 0)
        #expect(masteredSnapshot.progress(for: 1)?.vocabMastered == 1)
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
    @Test func progressLooksUpTheSelectedLevel() throws {
        let love = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let ba = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let snapshot = ProgressService.snapshot(
            cards: [love, ba],
            progress: [],
            catalog: CatalogFixture.catalog
        )
        #expect(snapshot.progress(for: 1)?.vocabTotal == 3)
        #expect(snapshot.progress(for: 1)?.vocabLearning == 1)
        #expect(snapshot.progress(for: 3)?.vocabTotal == 4)
        #expect(snapshot.progress(for: 3)?.vocabLearning == 2)
    }

    @MainActor
    @Test func lessonConfirmationIncrementsStoredProgress() throws {
        let context = try makeContext()
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordLessonConfirmation(hanzi: " 爱 ", in: context)
        let stored = ProgressService.progress(for: "爱", in: context)
        #expect(stored.lessonConfirmations == 2)
        #expect(stored.dailyMissionCompletions == 0)
        #expect(stored.recallDayKeys.count == 1)
    }

    @MainActor
    @Test func incorrectRecallRemovesOneProgressCount() throws {
        let context = try makeContext()
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordLessonMiss(hanzi: "爱", in: context)
        let stored = ProgressService.progress(for: "爱", in: context)
        #expect(stored.lessonConfirmations == 1)
        #expect(stored.recallDayKeys.count == 1)
    }

    @MainActor
    @Test func incorrectRecallDoesNotGoBelowZero() throws {
        let context = try makeContext()
        ProgressService.recordLessonMiss(hanzi: "爱", in: context)
        #expect(ProgressService.progress(for: "爱", in: context).lessonConfirmations == 0)
    }

    @MainActor
    @Test func missionCompletionsTrackDistinctDays() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = Date(timeIntervalSince1970: 1_700_086_400)
        ProgressService.recordMissionCompletion(hanzi: "爱", in: context, at: day1, calendar: calendar)
        ProgressService.recordMissionCompletion(hanzi: "爱", in: context, at: day1, calendar: calendar)
        ProgressService.recordMissionCompletion(hanzi: "爱", in: context, at: day2, calendar: calendar)
        let stored = ProgressService.progress(for: "爱", in: context)
        #expect(stored.dailyMissionCompletions == 3)
        #expect(stored.missionDayKeys.count == 2)
    }

    @MainActor
    @Test func markShownStoresLastShownAt() throws {
        let context = try makeContext()
        let shownAt = Date(timeIntervalSince1970: 1_700_000_000)
        let stored = ProgressService.markShown(hanzi: "爱", in: context, at: shownAt)
        #expect(stored.lastShownAt == shownAt)
        #expect(stored.lessonConfirmations == 0)
    }
}

struct VocabStarsTests {
    @Test func defaultProgressHasNoStars() {
        #expect(
            VocabStars.count(
                recallCount: 0,
                recallDayCount: 0,
                missionCount: 0,
                missionDayCount: 0,
                activitySpanDays: 0
            ) == 0
        )
    }

    @Test func oneStarNeedsFiveRecallsAcrossThreeDays() {
        #expect(
            VocabStars.count(
                recallCount: 5,
                recallDayCount: 2,
                missionCount: 0,
                missionDayCount: 0,
                activitySpanDays: 0
            ) == 0
        )
        #expect(
            VocabStars.count(
                recallCount: 4,
                recallDayCount: 3,
                missionCount: 0,
                missionDayCount: 0,
                activitySpanDays: 0
            ) == 0
        )
        #expect(
            VocabStars.count(
                recallCount: 5,
                recallDayCount: 3,
                missionCount: 0,
                missionDayCount: 0,
                activitySpanDays: 0
            ) == 1
        )
    }

    @Test func twoStarsNeedMissionsOnTwoDaysAfterOneStar() {
        #expect(
            VocabStars.count(
                recallCount: 5,
                recallDayCount: 3,
                missionCount: 2,
                missionDayCount: 1,
                activitySpanDays: 3
            ) == 1
        )
        #expect(
            VocabStars.count(
                recallCount: 5,
                recallDayCount: 3,
                missionCount: 2,
                missionDayCount: 2,
                activitySpanDays: 3
            ) == 2
        )
        #expect(
            VocabStars.count(
                recallCount: 0,
                recallDayCount: 0,
                missionCount: 2,
                missionDayCount: 2,
                activitySpanDays: 3
            ) == 0
        )
    }

    @Test func threeStarsNeedLongerPracticeSpan() {
        #expect(
            VocabStars.count(
                recallCount: 10,
                recallDayCount: 3,
                missionCount: 5,
                missionDayCount: 2,
                activitySpanDays: 13
            ) == 2
        )
        #expect(
            VocabStars.count(
                recallCount: 10,
                recallDayCount: 3,
                missionCount: 5,
                missionDayCount: 2,
                activitySpanDays: 14
            ) == 3
        )
    }

    @MainActor
    @Test func countReadsStoredProgress() throws {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            schema: Schema([Flashcard.self, ItemProgress.self]),
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: Schema([Flashcard.self, ItemProgress.self]),
            configurations: configuration
        )
        let context = ModelContext(container)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = Date(timeIntervalSince1970: 1_700_086_400)
        let day3 = Date(timeIntervalSince1970: 1_700_172_800)
        for date in [day1, day2, day3] {
            ProgressService.recordLessonConfirmation(hanzi: "爱", in: context, at: date, calendar: calendar)
        }
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context, at: day3, calendar: calendar)
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context, at: day3, calendar: calendar)
        let stored = ProgressService.progress(for: "爱", in: context)
        #expect(VocabStars.count(for: stored, calendar: calendar) == 1)
        #expect(VocabStars.needsMoreStars(for: stored))
        #expect(VocabStars.needsMoreStars(for: nil))
    }

    @Test func remainingMissionPracticePrefersWordsCloserToTheNextStar() {
        #expect(
            VocabStars.remainingMissionPracticeToNextStar(
                starCount: 1,
                missionCount: 1,
                missionDayCount: 1
            ) == 1
        )
        #expect(
            VocabStars.remainingMissionPracticeToNextStar(
                starCount: 1,
                missionCount: 0,
                missionDayCount: 0
            ) == 2
        )
        #expect(
            VocabStars.remainingMissionPracticeToNextStar(
                starCount: 2,
                missionCount: 4,
                missionDayCount: 2
            ) == 1
        )
        #expect(
            VocabStars.remainingMissionPracticeToNextStar(
                starCount: 0,
                missionCount: 0,
                missionDayCount: 0
            ) >
            VocabStars.remainingMissionPracticeToNextStar(
                starCount: 1,
                missionCount: 0,
                missionDayCount: 0
            )
        )
        #expect(
            VocabStars.missionPickWeight(remainingPractice: 1, starCount: 1) >
            VocabStars.missionPickWeight(remainingPractice: 2, starCount: 1)
        )
    }
}

struct CardPickerTests {
    private func candidate(
        _ key: String,
        lessons: Int = 0,
        missions: Int = 0,
        lastShownAt: Date? = nil,
        hasFlashcard: Bool = true,
        starCount: Int = 0,
        missionDays: Int = 0
    ) -> CardPickCandidate {
        CardPickCandidate(
            key: key,
            lessonConfirmations: lessons,
            dailyMissionCompletions: missions,
            lastShownAt: lastShownAt,
            hasFlashcard: hasFlashcard,
            starCount: starCount,
            missionDayCount: missionDays
        )
    }

    @Test func neverRepeatsLastCardWhenAnotherExists() {
        let candidates = [candidate("爱"), candidate("了")]
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<80 {
            let picked = CardPicker.pickCandidate(
                from: candidates,
                lastKey: "爱",
                rng: &rng
            )
            #expect(picked?.key == "了")
        }
    }

    @Test func skipsCooldownUnlessEveryCardIsCoolingDown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cooling = now.addingTimeInterval(-60)
        let candidates = [
            candidate("爱", lastShownAt: cooling),
            candidate("了")
        ]
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<80 {
            let picked = CardPicker.pickCandidate(
                from: candidates,
                now: now,
                rng: &rng
            )
            #expect(picked?.key == "了")
        }

        let allCooling = [
            candidate("爱", lastShownAt: cooling),
            candidate("了", lastShownAt: cooling)
        ]
        let fallback = CardPicker.pickCandidate(
            from: allCooling,
            lastKey: "爱",
            now: now,
            rng: &rng
        )
        #expect(fallback?.key == "了")
    }

    @Test func sessionCardsWaitUntilTheBagIsExhausted() {
        let candidates = [candidate("爱"), candidate("了"), candidate("把")]
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<80 {
            let picked = CardPicker.pickCandidate(
                from: candidates,
                sessionKeys: ["爱", "了"],
                rng: &rng
            )
            #expect(picked?.key == "把")
        }

        let wrapped = CardPicker.pickCandidate(
            from: candidates,
            sessionKeys: ["爱", "了", "把"],
            lastKey: "把",
            rng: &rng
        )
        #expect(wrapped?.key == "爱" || wrapped?.key == "了")
    }

    @Test func masteredCardsAreAMinorityOfPicks() {
        let candidates = [
            candidate("新", lessons: 1),
            candidate("习", lessons: 2),
            candidate("爱", lessons: 10, missions: 2),
            candidate("了", lessons: 10, missions: 2)
        ]
        var rng = SystemRandomNumberGenerator()
        var mastered = 0
        let samples = 400
        for _ in 0..<samples {
            let picked = CardPicker.pickCandidate(from: candidates, rng: &rng)
            if picked?.status == .mastered {
                mastered += 1
            }
        }
        #expect(mastered > 0)
        #expect(mastered < samples / 3)
    }

    @Test func fewerConfirmationsOutweighMany() {
        let candidates = [
            candidate("新", lessons: 0),
            candidate("熟", lessons: 9)
        ]
        var rng = SystemRandomNumberGenerator()
        var freshCount = 0
        let samples = 300
        for _ in 0..<samples {
            if CardPicker.pickCandidate(from: candidates, rng: &rng)?.key == "新" {
                freshCount += 1
            }
        }
        #expect(freshCount > samples / 2)
    }

    @MainActor
    @Test func pickUsesFlashcardProgressRecords() throws {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            schema: Schema([Flashcard.self, ItemProgress.self]),
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: Schema([Flashcard.self, ItemProgress.self]),
            configurations: configuration
        )
        let context = ModelContext(container)
        let fresh = Flashcard(hanzi: "新", pinyin: "xīn", english: "new")
        let cooling = Flashcard(hanzi: "了", pinyin: "le", english: "completed")
        let coolingProgress = ItemProgress(
            normalizedHanzi: "了",
            lastShownAt: .now
        )
        context.insert(fresh)
        context.insert(cooling)
        context.insert(coolingProgress)

        var rng = SystemRandomNumberGenerator()
        for _ in 0..<40 {
            let picked = CardPicker.pick(
                from: [fresh, cooling],
                progress: [coolingProgress],
                rng: &rng
            )
            #expect(picked?.hanzi == "新")
        }
    }

    @Test func newCatalogItemsArePreferredOverSavedCards() {
        let candidates = [
            candidate("新", hasFlashcard: false),
            candidate("习", hasFlashcard: false),
            candidate("爱", lessons: 2, hasFlashcard: true)
        ]
        var rng = SystemRandomNumberGenerator()
        var newCount = 0
        let samples = 300
        for _ in 0..<samples {
            if CardPicker.pickCandidate(from: candidates, rng: &rng)?.key != "爱" {
                newCount += 1
            }
        }
        #expect(newCount > samples * 2 / 3)
    }

    @MainActor
    @Test func missionTargetComesFromSelectedHSKLevelNotSavedCards() {
        var rng = SystemRandomNumberGenerator()
        let saved = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let level1Keys = Set(["了", "爱", "没（有）", "的"])
        for _ in 0..<40 {
            let picked = CardPicker.pickMissionTarget(
                level: 1,
                catalog: CatalogFixture.catalog,
                cards: [saved],
                rng: &rng
            )
            #expect(picked != nil)
            #expect(level1Keys.contains(picked?.hanzi ?? ""))
            #expect(picked?.hanzi != "把")
        }

        for _ in 0..<20 {
            let picked = CardPicker.pickMissionTarget(
                level: 3,
                catalog: CatalogFixture.catalog,
                cards: [saved],
                rng: &rng
            )
            #expect(picked?.hanzi == "把")
        }
    }

    @MainActor
    @Test func missionTargetDoesNotRequireSavedFlashcards() {
        var rng = SystemRandomNumberGenerator()
        let picked = CardPicker.pickMissionTarget(
            level: 1,
            catalog: CatalogFixture.catalog,
            cards: [],
            rng: &rng
        )
        #expect(picked != nil)
    }

    @Test func hardAndExtremeUseDualTargets() {
        #expect(!MissionDifficulty.easy.usesDualTargets)
        #expect(!MissionDifficulty.medium.usesDualTargets)
        #expect(MissionDifficulty.hard.usesDualTargets)
        #expect(MissionDifficulty.extreme.usesDualTargets)
    }

    @MainActor
    @Test func dualMissionTargetsAreOneVocabAndOneGrammar() {
        var rng = SystemRandomNumberGenerator()
        let vocabKeys = Set(["了", "爱", "没（有）"])
        let grammarKeys = Set(["了", "的"])
        for _ in 0..<30 {
            let picked = CardPicker.pickDualMissionTargets(
                level: 1,
                catalog: CatalogFixture.catalog,
                rng: &rng
            )
            #expect(picked != nil)
            #expect(picked?.vocabulary.focus == .vocabulary)
            #expect(picked?.grammar.focus == .grammar)
            #expect(vocabKeys.contains(picked?.vocabulary.hanzi ?? ""))
            #expect(grammarKeys.contains(picked?.grammar.hanzi ?? ""))
            #expect(picked?.vocabulary.hanzi != picked?.grammar.hanzi)
        }
    }

    @Test func discoverMissionsPreferSavedWordsThatNeedStars() {
        let candidates = [
            candidate("新", hasFlashcard: false),
            candidate("习", hasFlashcard: false),
            candidate("爱", lessons: 5, hasFlashcard: true, starCount: 1)
        ]
        var rng = SystemRandomNumberGenerator()
        var needsStars = 0
        let samples = 400
        for _ in 0..<samples {
            let picked = CardPicker.pickMissionCandidate(
                from: candidates,
                source: .discoverHSK,
                isVocabulary: true,
                lastKeys: [],
                rng: &rng
            )
            if picked?.key == "爱" {
                needsStars += 1
            }
        }
        #expect(needsStars > samples / 2)
        #expect(needsStars < samples)
    }

    @MainActor
    @Test func easyMissionsUsuallyPickVocabularyNotGrammar() {
        var rng = SystemRandomNumberGenerator()
        var vocab = 0
        let samples = 200
        for _ in 0..<samples {
            let picked = CardPicker.pickMissionTarget(
                level: 1,
                catalog: CatalogFixture.catalog,
                rng: &rng
            )
            if picked?.focus == .vocabulary {
                vocab += 1
            }
        }
        #expect(vocab > samples * 2 / 3)
        #expect(vocab < samples)
    }

    @Test func missionVocabPrefersWordsClosestToTheNextStar() {
        let candidates = [
            candidate("爱", missions: 1, hasFlashcard: true, starCount: 1, missionDays: 1),
            candidate("了", missions: 0, hasFlashcard: true, starCount: 1, missionDays: 0)
        ]
        var rng = SystemRandomNumberGenerator()
        var closer = 0
        let samples = 300
        for _ in 0..<samples {
            let picked = CardPicker.pickMissionCandidate(
                from: candidates,
                source: .practiceDeck,
                isVocabulary: true,
                lastKeys: [],
                rng: &rng
            )
            if picked?.key == "爱" {
                closer += 1
            }
        }
        #expect(closer > samples / 2)
        #expect(closer < samples)
    }

    @Test func practiceDeckMissionsStayOnSavedWordsAndFavorUnfinishedStars() {
        let candidates = [
            candidate("新", hasFlashcard: false),
            candidate("爱", hasFlashcard: true, starCount: 1),
            candidate("了", hasFlashcard: true, starCount: 3)
        ]
        var rng = SystemRandomNumberGenerator()
        var unfinished = 0
        let samples = 300
        for _ in 0..<samples {
            let picked = CardPicker.pickMissionCandidate(
                from: candidates,
                source: .practiceDeck,
                isVocabulary: true,
                lastKeys: [],
                rng: &rng
            )
            #expect(picked?.hasFlashcard == true)
            if picked?.key == "爱" {
                unfinished += 1
            }
        }
        #expect(unfinished > samples * 2 / 3)
    }

    @Test func missionVocabSourceLabels() {
        #expect(MissionVocabSource.discoverHSK.title == "Discover HSK")
        #expect(MissionVocabSource.practiceDeck.title == "My vocabulary")
        #expect(MissionVocabSource.practiceDeck.prefersSavedVocabulary)
        #expect(!MissionVocabSource.discoverHSK.prefersSavedVocabulary)
    }

    @MainActor
    @Test func practiceDeckPicksSavedWordsOutsideTheSelectedHSKLevel() {
        var rng = SystemRandomNumberGenerator()
        let saved = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")
        for _ in 0..<20 {
            let picked = CardPicker.pickMissionTarget(
                level: 1,
                catalog: CatalogFixture.catalog,
                cards: [saved],
                source: .practiceDeck,
                rng: &rng
            )
            #expect(picked?.hanzi == "蓝牙")
            #expect(picked?.focus == .vocabulary)
        }
    }

    @MainActor
    @Test func emptyPracticeDeckFallsBackToHSKCatalog() {
        var rng = SystemRandomNumberGenerator()
        let picked = CardPicker.pickMissionTarget(
            level: 3,
            catalog: CatalogFixture.catalog,
            cards: [],
            source: .practiceDeck,
            rng: &rng
        )
        #expect(picked?.hanzi == "把")
    }

    @MainActor
    @Test func practiceDeckDualTargetsKeepCatalogGrammar() {
        var rng = SystemRandomNumberGenerator()
        let saved = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let picked = CardPicker.pickDualMissionTargets(
            level: 1,
            catalog: CatalogFixture.catalog,
            cards: [saved],
            source: .practiceDeck,
            rng: &rng
        )
        #expect(picked?.vocabulary.hanzi == "爱")
        #expect(picked?.grammar.focus == .grammar)
        #expect(picked?.grammar.hanzi == "了" || picked?.grammar.hanzi == "的")
    }

    @MainActor
    @Test func dualMissionTargetsReturnNilWhenPoolsCollide() {
        var rng = SystemRandomNumberGenerator()
        let picked = CardPicker.pickDualMissionTargets(
            level: 3,
            catalog: CatalogFixture.catalog,
            rng: &rng
        )
        #expect(picked == nil)
    }

    @Test func dualMissionDecodesGrammarTarget() throws {
        let json = Data("""
        {
          "focus": "vocabulary",
          "hanzi": "爱",
          "pinyin": "ài",
          "meaning": "love",
          "grammarHanzi": "的",
          "grammarPinyin": "de",
          "grammarMeaning": "possessive particle",
          "situationChinese": "a",
          "situationPinyin": "a",
          "situationEnglish": "a",
          "taskChinese": "a",
          "taskPinyin": "a",
          "taskEnglish": "a"
        }
        """.utf8)
        let mission = try JSONDecoder().decode(DailyMission.self, from: json)
        #expect(mission.hasGrammarTarget)
        #expect(mission.hanzi == "爱")
        #expect(mission.grammarHanzi == "的")
    }
}

struct HSKGrammarMissionTargetTests {
    @Test func usablePhrasesIgnoreNotationAndKeepChinese() {
        let point = HSKGrammarPoint(
            id: "demo",
            level: 1,
            pattern: "可以、A一A、小—",
            matchTokens: ["可以", "A一A", "小……", "会"]
        )
        #expect(point.missionTargetPhrases == ["可以", "会"])
    }
}

struct FlashcardStudyLexiconTests {
    @Test func partOfSpeechLabelsUseShortSyntaxNames() {
        #expect(PartOfSpeechLabel.displayName(for: "noun") == "Noun")
        #expect(PartOfSpeechLabel.displayName(for: "adj") == "Adj")
        #expect(PartOfSpeechLabel.displayName(for: "adverb") == "Adv")
        #expect(PartOfSpeechLabel.displayName(for: "measure word") == "Measure word")
    }

    @Test func decodesPartOfSpeechStringOrArray() throws {
        let arrayJSON = Data(#"{"partOfSpeech":["noun","verb"],"characters":[],"sentences":[]}"#.utf8)
        let arrayLexicon = try JSONDecoder().decode(FlashcardStudyLexicon.self, from: arrayJSON)
        #expect(arrayLexicon.partOfSpeech == ["noun", "verb"])

        let stringJSON = Data(#"{"partOfSpeech":"noun, adj","characters":[],"sentences":[]}"#.utf8)
        let stringLexicon = try JSONDecoder().decode(FlashcardStudyLexicon.self, from: stringJSON)
        #expect(stringLexicon.partOfSpeech == ["noun", "adj"])
    }

    @Test func highlightsTargetWordCharactersInASentence() {
        let tokens = [
            FlashcardSentenceToken(hanzi: "他", pinyin: "tā"),
            FlashcardSentenceToken(hanzi: "是", pinyin: "shì"),
            FlashcardSentenceToken(hanzi: "警", pinyin: "jǐng"),
            FlashcardSentenceToken(hanzi: "察", pinyin: "chá"),
            FlashcardSentenceToken(hanzi: "。", pinyin: "")
        ]
        #expect(ExampleSentenceHighlight.targetIndices(in: tokens, hanzi: "警察") == [2, 3])
    }

    @Test func groupedWordsPreserveTheFullSentence() {
        let tokens = [
            FlashcardSentenceToken(hanzi: "他", pinyin: "tā"),
            FlashcardSentenceToken(hanzi: "是", pinyin: "shì"),
            FlashcardSentenceToken(hanzi: "警", pinyin: "jǐng"),
            FlashcardSentenceToken(hanzi: "察", pinyin: "chá"),
            FlashcardSentenceToken(hanzi: "。", pinyin: "")
        ]
        let groups = ExampleSentenceWords.grouped(tokens: tokens)
        #expect(groups.map(\.word.hanzi).joined() == "他是警察。")
        #expect(groups.flatMap(\.tokens) == tokens)
        #expect(groups.contains { $0.word.hanzi.contains("警") })
    }

    @Test func trailingPeriodStaysAttachedToPreviousWord() {
        let words = [
            MissionWord(hanzi: "他", pinyin: "tā", english: "he"),
            MissionWord(hanzi: "是", pinyin: "shì", english: "is"),
            MissionWord(hanzi: "警察", pinyin: "jǐngchá", english: "police"),
            MissionWord(hanzi: "。", pinyin: "", english: "")
        ]
        let items = ChineseSentenceLayout.items(from: words)
        #expect(items.map(\.displayHanzi) == ["他", "是", "警察。"])
        #expect(items.last?.word.hanzi == "警察")
    }

    @Test func groupedSentenceAttachesLeftoverPeriodForWrapping() {
        let tokens = [
            FlashcardSentenceToken(hanzi: "他", pinyin: "tā"),
            FlashcardSentenceToken(hanzi: "是", pinyin: "shì"),
            FlashcardSentenceToken(hanzi: "警", pinyin: "jǐng"),
            FlashcardSentenceToken(hanzi: "察", pinyin: "chá"),
            FlashcardSentenceToken(hanzi: "。", pinyin: "")
        ]
        let words = ExampleSentenceWords.grouped(tokens: tokens).map(\.word)
        let items = ChineseSentenceLayout.items(from: words)
        #expect(items.map(\.displayHanzi).joined() == "他是警察。")
        #expect(!items.contains { $0.displayHanzi == "。" })
        #expect(items.last?.displayHanzi.hasSuffix("。") == true)
    }

    @MainActor
    @Test func applyingLexiconStoresBreakdownAndFiveSentences() {
        let sentences = (1...5).map { index in
            FlashcardExampleSentence(
                tokens: [
                    FlashcardSentenceToken(hanzi: "爱", pinyin: "ài"),
                    FlashcardSentenceToken(hanzi: "。", pinyin: "")
                ],
                english: "Sentence \(index)"
            )
        }
        let lexicon = FlashcardStudyLexicon(
            partOfSpeech: ["noun"],
            characters: [
                FlashcardCharacterMeaning(hanzi: "爱", pinyin: "ài", meaning: "love")
            ],
            sentences: sentences
        )
        let card = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        card.applyStudyLexicon(lexicon)
        #expect(card.hasGeneratedStudyLexicon)
        #expect(card.partsOfSpeech == ["noun"])
        #expect(card.characterBreakdown.count == 1)
        #expect(card.exampleSentences.count == 5)
        #expect(card.exampleChinese == "爱。")
        #expect(card.exampleEnglish == "Sentence 1")
    }

    @MainActor
    @Test func applyingWordSyntaxLeavesSentencesUnchanged() {
        let card = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        card.applyExampleSentences([
            FlashcardExampleSentence(
                tokens: [FlashcardSentenceToken(hanzi: "爱", pinyin: "ài")],
                english: "love"
            )
        ])
        card.applyWordSyntax(
            FlashcardStudyLexicon(
                partOfSpeech: ["verb"],
                characters: [
                    FlashcardCharacterMeaning(hanzi: "爱", pinyin: "ài", meaning: "love")
                ],
                sentences: []
            )
        )
        #expect(card.hasGeneratedWordSyntax)
        #expect(!card.hasGeneratedExampleSentences)
        #expect(card.partsOfSpeech == ["verb"])
        #expect(card.exampleSentences.count == 1)
        #expect(card.exampleEnglish == "love")
    }
}

struct FlashcardSearchTests {
    @MainActor
    @Test func matchesHanziPinyinAndEnglish() {
        let card = Flashcard(hanzi: "警察", pinyin: "jǐng chá", english: "police")
        #expect(FlashcardSearch.matches(card, query: "警"))
        #expect(FlashcardSearch.matches(card, query: "jing"))
        #expect(FlashcardSearch.matches(card, query: "POLICE"))
        #expect(!FlashcardSearch.matches(card, query: "love"))
    }

    @MainActor
    @Test func matchesPinyinWithoutSpacesOrTones() {
        let card = Flashcard(hanzi: "警察", pinyin: "jǐng chá", english: "police")
        #expect(FlashcardSearch.matches(card, query: "jingcha"))
        #expect(FlashcardSearch.matches(card, query: "JǏNG"))
    }

    @MainActor
    @Test func emptyQueryKeepsAllCards() {
        let cards = [Flashcard(hanzi: "爱", pinyin: "ài", english: "love")]
        #expect(FlashcardSearch.filter(cards, query: "  ").map(\.hanzi) == ["爱"])
    }
}

struct VocabularyListSorterTests {
    @MainActor
    @Test func recentDescendingPutsNewestFirst() {
        let older = Flashcard(
            hanzi: "爱",
            pinyin: "ài",
            english: "love",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = Flashcard(
            hanzi: "把",
            pinyin: "bǎ",
            english: "ba",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let sections = VocabularyListSorter.sections(
            cards: [older, newer],
            mode: .recent,
            ascending: false
        )
        #expect(sections[0].cards.map(\.hanzi) == ["把", "爱"])
    }

    @MainActor
    @Test func partOfSpeechSectionsKeepUnknownLast() {
        let noun = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        noun.partOfSpeechJSON = "[\"noun\"]"
        let verb = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        verb.partOfSpeechJSON = "[\"verb\"]"
        let unknown = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")

        let sections = VocabularyListSorter.sections(
            cards: [unknown, verb, noun],
            mode: .partOfSpeech,
            ascending: true
        )
        #expect(sections.map(\.title) == ["Noun", "Verb", "Uncategorized"])
        #expect(sections.last?.cards.map(\.hanzi) == ["蓝牙"])
    }

    @MainActor
    @Test func hskSectionsKeepUnknownLast() {
        let hsk1 = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let hsk3 = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let unknown = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")

        let sections = VocabularyListSorter.sections(
            cards: [unknown, hsk3, hsk1],
            mode: .hskLevel,
            ascending: true,
            catalog: CatalogFixture.catalog
        )
        #expect(sections.map(\.title) == ["HSK 1", "HSK 3", "Uncategorized"])
        #expect(sections.last?.cards.map(\.hanzi) == ["蓝牙"])
    }

    @MainActor
    @Test func hskDescendingKeepsUnknownLast() {
        let hsk1 = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let hsk3 = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let unknown = Flashcard(hanzi: "蓝牙", pinyin: "lán yá", english: "bluetooth")

        let sections = VocabularyListSorter.sections(
            cards: [unknown, hsk3, hsk1],
            mode: .hskLevel,
            ascending: false,
            catalog: CatalogFixture.catalog
        )
        #expect(sections.map(\.title) == ["HSK 3", "HSK 1", "Uncategorized"])
        #expect(sections.last?.cards.map(\.hanzi) == ["蓝牙"])
    }

    @MainActor
    @Test func masterySectionsGroupByStarCount() {
        let none = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let one = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let three = Flashcard(hanzi: "了", pinyin: "le", english: "le")
        let oneProgress = ItemProgress(
            normalizedHanzi: "把",
            lessonConfirmations: 5,
            recallDaysJSON: DayKeyStore.encode(["2026-01-01", "2026-01-02", "2026-01-03"])
        )
        let threeProgress = ItemProgress(
            normalizedHanzi: "了",
            lessonConfirmations: 10,
            dailyMissionCompletions: 5,
            recallDaysJSON: DayKeyStore.encode(["2026-01-01", "2026-01-02", "2026-01-03"]),
            missionDaysJSON: DayKeyStore.encode(["2026-01-04", "2026-01-05"]),
            firstActivityAt: Date(timeIntervalSince1970: 0),
            lastActivityAt: Date(timeIntervalSince1970: 14 * 24 * 60 * 60)
        )

        let sections = VocabularyListSorter.sections(
            cards: [none, one, three],
            mode: .mastery,
            ascending: false,
            progress: [oneProgress, threeProgress]
        )
        #expect(sections.map(\.title) == ["3 stars", "1 star", "No stars"])
        #expect(sections[0].cards.map(\.hanzi) == ["了"])
        #expect(sections[1].cards.map(\.hanzi) == ["把"])
        #expect(sections[2].cards.map(\.hanzi) == ["爱"])
    }

    @MainActor
    @Test func masteryAscendingPutsNoStarsFirst() {
        let none = Flashcard(hanzi: "爱", pinyin: "ài", english: "love")
        let one = Flashcard(hanzi: "把", pinyin: "bǎ", english: "ba")
        let oneProgress = ItemProgress(
            normalizedHanzi: "把",
            lessonConfirmations: 5,
            recallDaysJSON: DayKeyStore.encode(["2026-01-01", "2026-01-02", "2026-01-03"])
        )
        let sections = VocabularyListSorter.sections(
            cards: [one, none],
            mode: .mastery,
            ascending: true,
            progress: [oneProgress]
        )
        #expect(sections.map(\.title) == ["No stars", "1 star"])
    }
}

struct MissionThemeSceneTests {
    @Test func everyThemeHasANonEmptyUniqueSceneBank() {
        for theme in MissionTheme.allCases {
            let bank = theme.sceneBank
            #expect(!bank.isEmpty)
            #expect(Set(bank).count == bank.count)
        }
    }

    @Test func travelScenesAreNotDominatedByBeijingAndShanghai() {
        let bank = MissionTheme.travel.sceneBank
        #expect(bank.count >= 30)
        let beijingOrShanghai = bank.filter {
            $0.localizedCaseInsensitiveContains("Beijing")
                || $0.localizedCaseInsensitiveContains("Shanghai")
                || $0.contains("北京")
                || $0.contains("上海")
        }
        #expect(beijingOrShanghai.isEmpty)
        let cityScenes = bank.filter {
            $0.contains("Chengdu")
                || $0.contains("Hangzhou")
                || $0.contains("Xi'an")
                || $0.contains("Chongqing")
                || $0.contains("Xiamen")
        }
        let placeTypeScenes = bank.filter {
            $0.localizedCaseInsensitiveContains("station")
                || $0.localizedCaseInsensitiveContains("airport")
                || $0.localizedCaseInsensitiveContains("hotel")
                || $0.localizedCaseInsensitiveContains("taxi")
                || $0.localizedCaseInsensitiveContains("hostel")
        }
        #expect(!cityScenes.isEmpty)
        #expect(!placeTypeScenes.isEmpty)
    }

    @Test func randomSceneCanExcludeTheLastOne() {
        let last = MissionTheme.travel.sceneBank[0]
        for _ in 0..<20 {
            #expect(MissionTheme.travel.randomScene(excluding: last) != last)
        }
    }

    @Test func situationAndTaskShapesStayVaried() {
        #expect(MissionPromptVariety.situationShapes.count >= 10)
        #expect(MissionPromptVariety.taskShapes.count >= 10)
        #expect(Set(MissionPromptVariety.situationShapes).count == MissionPromptVariety.situationShapes.count)
        #expect(Set(MissionPromptVariety.taskShapes).count == MissionPromptVariety.taskShapes.count)
        #expect(MissionPromptVariety.situationShapes.contains { $0.localizedCaseInsensitiveContains("WeChat") })
        #expect(MissionPromptVariety.situationShapes.contains { $0.localizedCaseInsensitiveContains("notice") })
        #expect(MissionPromptVariety.taskShapes.contains { $0.localizedCaseInsensitiveContains("question") })
        #expect(MissionPromptVariety.taskShapes.contains { $0.localizedCaseInsensitiveContains("refuse") })
    }
}

struct ActivityHistoryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func countsFromFirstActivityStartOnTheFirstEvent() {
        let first = date(2024, 3, 1)
        let later = date(2024, 3, 5)
        let events = [
            ActivityEvent(date: first, kind: .lesson),
            ActivityEvent(date: first, kind: .dailyMission),
            ActivityEvent(date: later, kind: .lesson)
        ]

        let days = ActivityHistory.countsFromFirstActivity(
            through: later,
            calendar: calendar,
            events: events
        )

        #expect(days.first?.date == first)
        #expect(days.last?.date == later)
        #expect(days.first?.count == 2)
        #expect(days.last?.count == 1)
        #expect(days.count == 5)
    }

    @Test func emptyHistoryFallsBackToThirtyDays() {
        let days = ActivityHistory.countsFromFirstActivity(
            through: date(2024, 3, 31),
            calendar: calendar,
            events: []
        )
        #expect(days.count == 30)
        #expect(days.allSatisfy { $0.count == 0 })
    }
}

struct ContributionGridLayoutTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func startsAtJanuaryOfTheFirstActivityYear() {
        let first = date(2023, 12, 8)
        let now = date(2024, 9, 8)
        let layout = ContributionGridLayout(firstActivity: first, now: now, calendar: calendar)

        #expect(layout.start == date(2023, 1, 1))
        #expect(layout.date(column: 0, row: layout.leadingEmpty) == layout.start)
        #expect(layout.column(containing: now) != nil)
        #expect(layout.monthLabel(for: 0)?.contains("Jan") == true)
        #expect(layout.monthLabel(for: 0)?.contains("2023") == true)
    }

    @Test func withoutActivityStartsAtTheCurrentMonth() {
        let now = date(2024, 9, 8)
        let layout = ContributionGridLayout(firstActivity: nil, now: now, calendar: calendar)
        #expect(layout.start == date(2024, 9, 1))
    }

    @MainActor
    @Test func lessonAndMissionIncreaseTodaysActivity() throws {
        let context = try makeContext()
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordLessonConfirmation(hanzi: "爱", in: context)
        ProgressService.recordMissionCompletion(hanzi: "爱", in: context)

        let activities = try context.fetch(FetchDescriptor<DailyActivity>())
        #expect(activities.count == 1)
        #expect(activities.first?.count == 3)
    }
}

struct StreakCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 1
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func busiestDayStaysFullyDarkAndQuieterDaysAreLighter() {
        let peak = 4
        #expect(StreakCalendar.opacity(count: peak, peak: peak) == 1)
        let quieter = StreakCalendar.opacity(count: 2, peak: peak)
        let quietest = StreakCalendar.opacity(count: 1, peak: peak)
        #expect(quieter < 1)
        #expect(quietest < quieter)
        #expect(quietest > StreakCalendar.emptyOpacity)
        #expect(StreakCalendar.opacity(count: 0, peak: peak) == StreakCalendar.emptyOpacity)
    }

    @Test func aSingleActivityLevelStaysAtFullDarkness() {
        #expect(StreakCalendar.opacity(count: 1, peak: 1) == 1)
        #expect(StreakCalendar.opacity(count: 3, peak: 3) == 1)
    }

    @Test func streakCountsConsecutiveStudyDays() {
        let today = day(2026, 9, 27)
        let counts = [
            day(2026, 9, 27): 2,
            day(2026, 9, 26): 1,
            day(2026, 9, 25): 4,
            day(2026, 9, 23): 3
        ]
        #expect(StreakCalendar.currentStreak(dayCounts: counts, now: today, calendar: calendar) == 3)
    }

    @Test func emptyTodayStillCountsYesterdaysStreak() {
        let today = day(2026, 9, 27)
        let counts = [
            day(2026, 9, 26): 2,
            day(2026, 9, 25): 1
        ]
        #expect(StreakCalendar.currentStreak(dayCounts: counts, now: today, calendar: calendar) == 2)
    }

    @Test func aMissedDayBreaksTheStreak() {
        let today = day(2026, 9, 27)
        let counts = [
            day(2026, 9, 25): 4
        ]
        #expect(StreakCalendar.currentStreak(dayCounts: counts, now: today, calendar: calendar) == 0)
    }

    @Test func peakIgnoresDaysAfterToday() {
        let today = day(2026, 9, 27)
        let days = [day(2026, 9, 26), day(2026, 9, 27), day(2026, 9, 28)]
        let counts = [
            day(2026, 9, 26): 2,
            day(2026, 9, 28): 9
        ]
        #expect(StreakCalendar.peak(in: days, dayCounts: counts, through: today, calendar: calendar) == 2)
    }
}
