//
//  ProgressSnapshot.swift
//  LearnChinese
//

import Foundation

struct HSKLevelProgress: Equatable, Sendable, Identifiable {
    var id: Int { level }
    let level: Int
    let vocabTotal: Int
    let vocabLearning: Int
    let vocabMastered: Int
    let grammarTotal: Int
    let grammarLearning: Int
    let grammarMastered: Int

    var vocabAdded: Int { vocabLearning + vocabMastered }
    var grammarAdded: Int { grammarLearning + grammarMastered }
}

struct CustomProgress: Equatable, Sendable {
    let learning: Int
    let mastered: Int
    var added: Int { learning + mastered }
}

struct HSKProgressSnapshot: Equatable, Sendable {
    let levels: [HSKLevelProgress]
    let custom: CustomProgress

    func summary(in range: HSKRange) -> (vocabAdded: Int, vocabTotal: Int, grammarAdded: Int, grammarTotal: Int) {
        let slice = levels.filter { range.contains($0.level) }
        return (
            slice.reduce(0) { $0 + $1.vocabAdded },
            slice.reduce(0) { $0 + $1.vocabTotal },
            slice.reduce(0) { $0 + $1.grammarAdded },
            slice.reduce(0) { $0 + $1.grammarTotal }
        )
    }
}

enum TrackedItemKind: String, Equatable, Sendable {
    case vocab
    case grammar
    case custom
}

struct TrackedItem: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let kind: TrackedItemKind
    let level: Int?
    let status: LearningStatus
    let lessonConfirmations: Int
    let dailyMissionCompletions: Int
}
