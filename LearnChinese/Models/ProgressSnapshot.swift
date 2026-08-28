//
//  ProgressSnapshot.swift
//  LearnChinese
//

import Foundation

struct HSKLevelProgress: Equatable, Sendable, Identifiable {
    var id: Int { level }
    let level: Int
    /// Vocabulary through this HSK level, including every earlier level.
    let vocabTotal: Int
    let vocabLearning: Int
    let vocabMastered: Int

    var vocabNew: Int { max(0, vocabTotal - vocabLearning - vocabMastered) }
    var vocabAdded: Int { vocabLearning + vocabMastered }
}

struct HSKProgressSnapshot: Equatable, Sendable {
    let levels: [HSKLevelProgress]

    func progress(for level: Int) -> HSKLevelProgress? {
        levels.first { $0.level == level }
    }
}
