//
//  VocabularySearch.swift
//  LearnChinese
//

import Foundation

enum FlashcardSearch {
    static func filter(_ cards: [Flashcard], query: String) -> [Flashcard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cards }
        return cards.filter { matches($0, query: trimmed) }
    }

    static func matches(_ card: Flashcard, query: String) -> Bool {
        let foldedQuery = fold(query)
        guard !foldedQuery.isEmpty else { return true }

        if fold(card.hanzi).contains(foldedQuery) { return true }
        if fold(card.pinyin).contains(foldedQuery) { return true }
        if fold(card.english).contains(foldedQuery) { return true }
        if fold(card.displayEnglish).contains(foldedQuery) { return true }

        let compactQuery = compact(foldedQuery)
        guard !compactQuery.isEmpty else { return false }
        return compact(fold(card.pinyin)).contains(compactQuery)
            || compact(fold(card.hanzi)).contains(compactQuery)
    }

    private static func fold(_ value: String) -> String {
        value.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    private static func compact(_ value: String) -> String {
        value.filter { !$0.isWhitespace && !$0.isNewline && $0 != "'" && $0 != "’" }
    }
}
