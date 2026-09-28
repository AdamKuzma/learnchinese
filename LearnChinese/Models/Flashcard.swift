//
//  Flashcard.swift
//  LearnChinese
//

import Foundation
import SwiftData

enum FlashcardKind: String, Codable, CaseIterable, Sendable {
    case vocabulary
    case grammar
}

@Model
final class Flashcard {
    var hanzi: String
    var pinyin: String
    var english: String
    var createdAt: Date
    var exampleChinese: String?
    var exampleEnglish: String?
    var memoryHint: String?
    var memoryHintChinese: String?
    var memoryHintEnglish: String?
    var detailsGeneratedAt: Date?
    @Attribute var kind: String = FlashcardKind.vocabulary.rawValue
    var partOfSpeechJSON: String?
    var characterBreakdownJSON: String?
    var exampleSentencesJSON: String?

    var cardKind: FlashcardKind {
        get { FlashcardKind(rawValue: kind) ?? .vocabulary }
        set { kind = newValue.rawValue }
    }

    init(
        hanzi: String,
        pinyin: String,
        english: String,
        kind: FlashcardKind = .vocabulary,
        createdAt: Date = .now
    ) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = kind == .vocabulary ? english.capitalizingFirstLetter() : english
        self.kind = kind.rawValue
        self.createdAt = createdAt
    }

    var displayEnglish: String {
        cardKind == .vocabulary ? english.capitalizingFirstLetter() : english
    }

    static func capitalizeStoredVocabularyEnglish(in context: ModelContext) {
        guard let cards = try? context.fetch(FetchDescriptor<Flashcard>()) else { return }
        var didChange = false
        for card in cards where card.cardKind == .vocabulary {
            let capitalized = card.english.capitalizingFirstLetter()
            guard card.english != capitalized else { continue }
            card.english = capitalized
            didChange = true
        }
        if didChange {
            try? context.save()
        }
    }

    /// Older stores never persisted `kind`, so grammar cards reload as vocabulary.
    static func restoreSavedKinds(in context: ModelContext, catalog: HSKCatalog = .bundled) {
        guard let cards = try? context.fetch(FetchDescriptor<Flashcard>()) else { return }
        var didChange = false
        for card in cards where card.cardKind == .vocabulary {
            let fromCatalog = catalog.preferredSavedKind(for: card.hanzi) == .grammar
            guard fromCatalog || looksLikeGrammarDefinition(card.english) else { continue }
            card.cardKind = .grammar
            didChange = true
        }
        if didChange {
            try? context.save()
        }
    }

    /// Mission grammar meanings are long explanations, usually "Used to…" / "Used after…".
    static func looksLikeGrammarDefinition(_ english: String) -> Bool {
        let trimmed = english.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16 else { return false }
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("used") else { return false }
        guard let separator = lower.dropFirst(4).first else { return false }
        return separator == " " || separator == "-" || separator == ","
    }

    var hasGeneratedDetails: Bool {
        hasGeneratedStudyLexicon && hasGeneratedMemoryHint
    }

    var hasGeneratedSentence: Bool {
        !(exampleChinese?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        !(exampleEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var hasGeneratedMemoryHint: Bool {
        !(memoryHintChinese?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        !(memoryHintEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var hasGeneratedWordSyntax: Bool {
        !partsOfSpeech.isEmpty && !characterBreakdown.isEmpty
    }

    var hasGeneratedExampleSentences: Bool {
        exampleSentences.count >= 5
    }

    var hasGeneratedStudyLexicon: Bool {
        hasGeneratedWordSyntax && hasGeneratedExampleSentences
    }

    var partsOfSpeech: [String] {
        Self.decode([String].self, from: partOfSpeechJSON) ?? []
    }

    var characterBreakdown: [FlashcardCharacterMeaning] {
        Self.decode([FlashcardCharacterMeaning].self, from: characterBreakdownJSON) ?? []
    }

    var exampleSentences: [FlashcardExampleSentence] {
        Self.decode([FlashcardExampleSentence].self, from: exampleSentencesJSON) ?? []
    }

    func applyWordSyntax(_ lexicon: FlashcardStudyLexicon) {
        partOfSpeechJSON = Self.encode(lexicon.partOfSpeech)
        characterBreakdownJSON = Self.encode(lexicon.characters)
        detailsGeneratedAt = .now
    }

    func applyStudyLexicon(_ lexicon: FlashcardStudyLexicon) {
        applyWordSyntax(lexicon)
        applyExampleSentences(lexicon.sentences)
    }

    func applyExampleSentences(_ sentences: [FlashcardExampleSentence]) {
        exampleSentencesJSON = Self.encode(sentences)
        if let first = sentences.first, !first.chinese.isEmpty {
            exampleChinese = first.chinese
            exampleEnglish = first.english
        }
        detailsGeneratedAt = .now
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from json: String?) -> T? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return self }
        return first.uppercased() + trimmed.dropFirst()
    }
}
