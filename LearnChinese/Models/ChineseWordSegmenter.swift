import Foundation
import NaturalLanguage

enum ChineseWordSegmenter {
    static func resolvedWords(sentence: String, provided: [MissionWord]) -> [MissionWord] {
        let compactSentence = compact(sentence)
        let compactProvided = compact(provided.map(\.hanzi).joined())
        if !provided.isEmpty, compactProvided == compactSentence {
            return provided
        }
        return segment(sentence)
    }

    static func segment(_ text: String) -> [MissionWord] {
        guard !text.isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.simplifiedChinese)

        var words: [MissionWord] = []
        var cursor = text.startIndex

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if cursor < range.lowerBound {
                words.append(MissionWord(hanzi: String(text[cursor..<range.lowerBound]), pinyin: "", english: ""))
            }
            words.append(MissionWord(hanzi: String(text[range]), pinyin: "", english: ""))
            cursor = range.upperBound
            return true
        }

        if cursor < text.endIndex {
            words.append(MissionWord(hanzi: String(text[cursor...]), pinyin: "", english: ""))
        }

        return words
    }

    private static func compact(_ text: String) -> String {
        text.filter { !$0.isWhitespace && !$0.isNewline }
    }
}

extension Character {
    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value)
                || (0x4E00...0x9FFF).contains(scalar.value)
                || (0xF900...0xFAFF).contains(scalar.value)
                || (0x20000...0x2A6DF).contains(scalar.value)
        }
    }
}
