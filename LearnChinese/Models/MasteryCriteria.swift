//
//  MasteryCriteria.swift
//  LearnChinese
//

import Foundation

enum LearningStatus: String, Equatable, Sendable, CaseIterable {
    case notLearned
    case learning
    case mastered

    var title: String {
        switch self {
        case .notLearned: return "New"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }
}

enum MasteryCriteria {
    static let requiredLessonConfirmations = 10
    static let requiredDailyMissionCompletions = 2

    static func status(
        hasFlashcard: Bool,
        lessonConfirmations: Int,
        dailyMissionCompletions: Int
    ) -> LearningStatus {
        guard hasFlashcard else { return .notLearned }
        if lessonConfirmations >= requiredLessonConfirmations,
           dailyMissionCompletions >= requiredDailyMissionCompletions {
            return .mastered
        }
        return .learning
    }
}
