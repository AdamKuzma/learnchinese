//
//  Flashcard.swift
//  LearnChinese
//

import Foundation
import SwiftData

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

    init(hanzi: String, pinyin: String, english: String, createdAt: Date = .now) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
        self.createdAt = createdAt
    }

    var hasGeneratedDetails: Bool {
        hasGeneratedSentence && hasGeneratedMemoryHint
    }

    var hasGeneratedSentence: Bool {
        !(exampleChinese?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        !(exampleEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var hasGeneratedMemoryHint: Bool {
        !(memoryHintChinese?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
        !(memoryHintEnglish?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
