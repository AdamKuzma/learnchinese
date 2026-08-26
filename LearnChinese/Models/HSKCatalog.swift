//
//  HSKCatalog.swift
//  LearnChinese
//

import Foundation

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

    let vocab: [HSKVocabWord]
    let grammar: [HSKGrammarPoint]

    private let vocabByHanzi: [String: HSKVocabWord]
    private let grammarByToken: [String: [HSKGrammarPoint]]
    private let vocabByLevel: [Int: [HSKVocabWord]]
    private let grammarByLevel: [Int: [HSKGrammarPoint]]

    init(vocab: [HSKVocabWord], grammar: [HSKGrammarPoint]) {
        self.vocab = vocab
        self.grammar = grammar

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
        return HSKCatalog(vocab: vocab, grammar: grammar)
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
}

private enum HSKResource {
    static var bundle: Bundle {
        Bundle(for: HSKResourceToken.self)
    }
}

private final class HSKResourceToken {}
