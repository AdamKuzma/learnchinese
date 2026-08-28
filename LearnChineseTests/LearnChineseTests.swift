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
        let configuration = ModelConfiguration(UUID().uuidString, schema: Schema([Flashcard.self, ItemProgress.self]), isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema([Flashcard.self, ItemProgress.self]), configurations: configuration)
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

struct CardPickerTests {
    private func candidate(
        _ key: String,
        lessons: Int = 0,
        missions: Int = 0,
        lastShownAt: Date? = nil
    ) -> CardPickCandidate {
        CardPickCandidate(
            key: key,
            lessonConfirmations: lessons,
            dailyMissionCompletions: missions,
            lastShownAt: lastShownAt
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

struct PullToRevealSearchTests {
    @Test func momentumOverscrollDoesNotRevealSearch() {
        var state = PullToRevealSearchState()
        state.handleScroll(offsetFromTop: -80, phase: .coasting, isLockedOpen: false)
        #expect(state.revealedHeight == 0)
        #expect(!state.isExpanded)
    }

    @Test func userPullRevealsSearch() {
        var state = PullToRevealSearchState()
        state.handleScroll(offsetFromTop: -20, phase: .userDragging, isLockedOpen: false)
        #expect(state.revealedHeight == 20)
        #expect(!state.isExpanded)
    }

    @Test func releasingPastThresholdPinsSearch() {
        var state = PullToRevealSearchState()
        state.handleScroll(offsetFromTop: -40, phase: .userDragging, isLockedOpen: false)
        state.handleDragEnded(isLockedOpen: false)
        #expect(state.isExpanded)
        #expect(state.revealedHeight == PullToRevealSearchState.barHeight)
    }

    @Test func releasingBeforeThresholdHidesSearch() {
        var state = PullToRevealSearchState()
        state.handleScroll(offsetFromTop: -10, phase: .userDragging, isLockedOpen: false)
        state.handleDragEnded(isLockedOpen: false)
        #expect(!state.isExpanded)
        #expect(state.revealedHeight == 0)
    }

    @Test func scrollingDownCollapsesUnlockedSearch() {
        var state = PullToRevealSearchState()
        state.expand()
        state.handleScroll(offsetFromTop: 30, phase: .userDragging, isLockedOpen: false)
        #expect(!state.isExpanded)
    }

    @Test func lockedSearchStaysOpenWhenScrolling() {
        var state = PullToRevealSearchState()
        state.expand()
        state.handleScroll(offsetFromTop: 30, phase: .userDragging, isLockedOpen: true)
        #expect(state.isExpanded)
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
}
