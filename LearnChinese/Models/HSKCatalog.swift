//
//  HSKCatalog.swift
//  LearnChinese
//

import Foundation

enum HSKSyllabus {
    /// Official HSK 3.0 (2026) cumulative vocabulary sizes.
    static let cumulativeVocabulary: [Int: Int] = [
        1: 300,
        2: 500,
        3: 1_000,
        4: 2_000,
        5: 3_600,
        6: 5_400
    ]
}

struct HSKVocabWord: Codable, Equatable, Sendable, Hashable, Identifiable {
    var id: String { hanzi }
    let hanzi: String
    let pinyin: String
    let level: Int
}

struct HSKGrammarPoint: Codable, Equatable, Sendable, Hashable, Identifiable {
    let id: String
    let level: Int
    let pattern: String
    let matchTokens: [String]
}

struct HSKCatalog: Sendable {
    static let bundled: HSKCatalog = {
        HSKCatalog.load(from: HSKResource.bundle) ?? HSKCatalog(vocab: [], grammar: [])
    }()

    static func warm() {
        _ = bundled
    }

    let vocab: [HSKVocabWord]
    let grammar: [HSKGrammarPoint]
    let publishedCumulativeTotals: [Int: Int]

    private let vocabByHanzi: [String: HSKVocabWord]
    private let grammarByToken: [String: [HSKGrammarPoint]]
    private let vocabByLevel: [Int: [HSKVocabWord]]
    private let grammarByLevel: [Int: [HSKGrammarPoint]]
    private let grammarOnlyTargets: Set<String>

    init(
        vocab: [HSKVocabWord],
        grammar: [HSKGrammarPoint],
        publishedCumulativeTotals: [Int: Int] = [:]
    ) {
        self.vocab = vocab
        self.grammar = grammar
        self.publishedCumulativeTotals = publishedCumulativeTotals

        var vocabIndex: [String: HSKVocabWord] = [:]
        var vocabLevels: [Int: [HSKVocabWord]] = [:]
        for word in vocab {
            let official = HanziNormalizer.normalize(word.hanzi)
            vocabIndex[official] = word
            vocabLevels[word.level, default: []].append(word)
        }
        for word in vocab {
            for key in HanziNormalizer.lookupKeys(for: word.hanzi) where vocabIndex[key] == nil {
                vocabIndex[key] = word
            }
        }

        var grammarIndex: [String: [HSKGrammarPoint]] = [:]
        var grammarLevels: [Int: [HSKGrammarPoint]] = [:]
        for point in grammar {
            grammarLevels[point.level, default: []].append(point)
            var tokens = Set(point.matchTokens.map(HanziNormalizer.normalize))
            tokens.insert(HanziNormalizer.normalize(point.pattern))
            for token in tokens where !token.isEmpty {
                for key in HanziNormalizer.lookupKeys(for: token) {
                    grammarIndex[key, default: []].append(point)
                }
            }
        }

        self.vocabByHanzi = vocabIndex
        self.grammarByToken = grammarIndex
        self.vocabByLevel = vocabLevels
        self.grammarByLevel = grammarLevels

        var grammarOnly: Set<String> = []
        for point in grammar {
            for phrase in point.missionTargetPhrases {
                let keys = HanziNormalizer.lookupKeys(for: phrase)
                guard keys.contains(where: { vocabIndex[$0] != nil }) == false else { continue }
                for key in keys where !key.isEmpty {
                    grammarOnly.insert(key)
                }
            }
        }
        self.grammarOnlyTargets = grammarOnly
    }

    static func load(from bundle: Bundle) -> HSKCatalog? {
        guard
            let vocabURL = bundle.url(forResource: "hsk-vocabulary", withExtension: "json"),
            let grammarURL = bundle.url(forResource: "hsk-grammar", withExtension: "json")
        else {
            return nil
        }
        return load(vocabURL: vocabURL, grammarURL: grammarURL)
    }

    static func load(vocabURL: URL, grammarURL: URL) -> HSKCatalog? {
        let decoder = JSONDecoder()
        guard
            let vocabData = try? Data(contentsOf: vocabURL),
            let grammarData = try? Data(contentsOf: grammarURL),
            let vocab = try? decoder.decode([HSKVocabWord].self, from: vocabData),
            let grammar = try? decoder.decode([HSKGrammarPoint].self, from: grammarData)
        else {
            return nil
        }
        return HSKCatalog(
            vocab: vocab,
            grammar: grammar,
            publishedCumulativeTotals: HSKSyllabus.cumulativeVocabulary
        )
    }

    func vocab(for hanzi: String) -> HSKVocabWord? {
        for key in HanziNormalizer.lookupKeys(for: hanzi) {
            if let word = vocabByHanzi[key] {
                return word
            }
        }
        return nil
    }

    func grammarPoints(for hanzi: String) -> [HSKGrammarPoint] {
        var seen = Set<String>()
        var matches: [HSKGrammarPoint] = []
        for key in HanziNormalizer.lookupKeys(for: hanzi) {
            for point in grammarByToken[key] ?? [] where seen.insert(point.id).inserted {
                matches.append(point)
            }
        }
        return matches
    }

    func vocab(level: Int) -> [HSKVocabWord] {
        vocabByLevel[level] ?? []
    }

    func grammar(level: Int) -> [HSKGrammarPoint] {
        grammarByLevel[level] ?? []
    }

    func vocabTotal(level: Int) -> Int {
        vocab(level: level).count
    }

    func grammarTotal(level: Int) -> Int {
        grammar(level: level).count
    }

    func isCustom(hanzi: String) -> Bool {
        vocab(for: hanzi) == nil && grammarPoints(for: hanzi).isEmpty
    }

    /// Grammar-only HSK targets. Words that also appear in the vocab list stay vocabulary.
    func preferredSavedKind(for hanzi: String) -> FlashcardKind {
        let keys = HanziNormalizer.lookupKeys(for: hanzi)
        if keys.contains(where: { grammarOnlyTargets.contains($0) }) {
            return .grammar
        }
        return .vocabulary
    }
}

extension HSKGrammarPoint {
    var missionTargetPhrases: [String] {
        var seen = Set<String>()
        var phrases: [String] = []
        let parts = pattern
            .split(separator: "、", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for piece in parts + matchTokens {
            let normalized = HanziNormalizer.normalize(piece)
            guard Self.isMissionTargetPhrase(normalized), seen.insert(normalized).inserted else { continue }
            phrases.append(normalized)
        }
        return phrases
    }

    private static func isMissionTargetPhrase(_ value: String) -> Bool {
        guard (1...8).contains(value.count) else { return false }
        guard value.contains(where: \.isCJK) else { return false }
        if value.contains(where: { $0.isASCII && $0.isLetter }) { return false }
        if value.contains("…") || value.contains("...") || value.contains("—") || value.contains("－") {
            return false
        }
        if value.contains("（") || value.contains("(") { return false }
        return true
    }
}

private enum HSKResource {
    static var bundle: Bundle {
        Bundle(for: HSKResourceToken.self)
    }
}

private final class HSKResourceToken {}
