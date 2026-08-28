//
//  FlashcardStudyLexicon.swift
//  LearnChinese
//

import Foundation

struct FlashcardStudyLexicon: Codable, Equatable, Sendable {
    var partOfSpeech: [String]
    var characters: [FlashcardCharacterMeaning]
    var sentences: [FlashcardExampleSentence]

    enum CodingKeys: String, CodingKey {
        case partOfSpeech, characters, sentences
    }

    init(
        partOfSpeech: [String],
        characters: [FlashcardCharacterMeaning],
        sentences: [FlashcardExampleSentence]
    ) {
        self.partOfSpeech = partOfSpeech
        self.characters = characters
        self.sentences = sentences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        partOfSpeech = Self.decodeStringList(container, key: .partOfSpeech)
        characters = try container.decodeIfPresent([FlashcardCharacterMeaning].self, forKey: .characters) ?? []
        sentences = try container.decodeIfPresent([FlashcardExampleSentence].self, forKey: .sentences) ?? []
    }

    private static func decodeStringList(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> [String] {
        if let values = try? container.decode([String].self, forKey: key) {
            return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let value = try? container.decode(String.self, forKey: key) {
            return value
                .split { $0 == "," || $0 == "/" || $0 == ";" || $0 == "、" }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}

struct FlashcardCharacterMeaning: Codable, Equatable, Sendable {
    var hanzi: String
    var pinyin: String
    var meaning: String
}

struct FlashcardExampleSentence: Codable, Equatable, Sendable {
    var tokens: [FlashcardSentenceToken]
    var english: String

    enum CodingKeys: String, CodingKey {
        case tokens, english
    }

    var chinese: String {
        tokens.map(\.hanzi).joined()
    }

    init(tokens: [FlashcardSentenceToken], english: String) {
        self.tokens = tokens
        self.english = english
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = try container.decodeIfPresent([FlashcardSentenceToken].self, forKey: .tokens) ?? []
        english = try container.decodeIfPresent(String.self, forKey: .english) ?? ""
    }
}

struct FlashcardSentenceToken: Codable, Equatable, Sendable {
    var hanzi: String
    var pinyin: String
}

enum PartOfSpeechLabel {
    static func displayName(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "n", "noun": return "Noun"
        case "v", "verb": return "Verb"
        case "adj", "adjective": return "Adj"
        case "adv", "adverb": return "Adv"
        case "mw", "measure word", "classifier", "measure": return "Measure word"
        case "part", "particle": return "Particle"
        case "pron", "pronoun": return "Pronoun"
        case "conj", "conjunction": return "Conjunction"
        case "prep", "preposition": return "Prep"
        case "num", "numeral", "number": return "Numeral"
        case "idiom": return "Idiom"
        case "pattern", "grammar", "grammar pattern": return "Pattern"
        default:
            return raw.capitalizingFirstLetter()
        }
    }
}

enum ExampleSentenceHighlight {
    static func targetIndices(in tokens: [FlashcardSentenceToken], hanzi: String) -> Set<Int> {
        let target = hanzi.filter(\.isCJK)
        guard !target.isEmpty, !tokens.isEmpty else { return [] }

        let pieces = tokens.map { $0.hanzi.filter(\.isCJK) }
        for start in pieces.indices {
            var combined = ""
            for end in start..<pieces.count {
                combined += pieces[end]
                if combined == target {
                    return Set(start...end)
                }
                if combined.count >= target.count {
                    break
                }
            }
        }
        return []
    }
}

struct ExampleSentenceWordGroup: Equatable {
    var word: MissionWord
    var tokens: [FlashcardSentenceToken]
    var tokenIndices: [Int]
}

enum ExampleSentenceWords {
    static func grouped(tokens: [FlashcardSentenceToken]) -> [ExampleSentenceWordGroup] {
        guard !tokens.isEmpty else { return [] }

        let chinese = tokens.map(\.hanzi).joined()
        let words = ChineseWordSegmenter.segment(chinese)
        var groups: [ExampleSentenceWordGroup] = []
        var index = 0

        for word in words {
            guard index < tokens.count else { break }
            var joined = ""
            let start = index
            while index < tokens.count {
                joined += tokens[index].hanzi
                index += 1
                if joined == word.hanzi || joined.count >= word.hanzi.count {
                    break
                }
            }
            let slice = Array(tokens[start..<index])
            let pinyin = slice.map(\.pinyin).filter { !$0.isEmpty }.joined(separator: " ")
            groups.append(
                ExampleSentenceWordGroup(
                    word: MissionWord(
                        hanzi: joined,
                        pinyin: pinyin.isEmpty ? word.pinyin : pinyin,
                        english: word.english
                    ),
                    tokens: slice,
                    tokenIndices: Array(start..<index)
                )
            )
        }

        if index < tokens.count {
            let slice = Array(tokens[index...])
            groups.append(
                ExampleSentenceWordGroup(
                    word: MissionWord(
                        hanzi: slice.map(\.hanzi).joined(),
                        pinyin: slice.map(\.pinyin).filter { !$0.isEmpty }.joined(separator: " "),
                        english: ""
                    ),
                    tokens: slice,
                    tokenIndices: Array(index..<tokens.count)
                )
            )
        }

        return groups
    }
}
