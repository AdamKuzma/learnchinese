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
        case .notLearned: return "Not learned"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }
}

enum MasteryCriteria {
    static let requiredLessonConfirmations = 10
    static let requiredDailyMissionCompletions = 2
    static let displayedStars = 3

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

    /// 0 with no flashcard, 1 once added, 2 at halfway progress, 3 only when mastered.
    static func stars(
        hasFlashcard: Bool,
        lessonConfirmations: Int,
        dailyMissionCompletions: Int
    ) -> Int {
        guard hasFlashcard else { return 0 }
        if status(
            hasFlashcard: true,
            lessonConfirmations: lessonConfirmations,
            dailyMissionCompletions: dailyMissionCompletions
        ) == .mastered {
            return displayedStars
        }
        let halfwayQuiz = lessonConfirmations >= requiredLessonConfirmations / 2
        let startedMissions = dailyMissionCompletions >= 1
        if halfwayQuiz || startedMissions { return 2 }
        return 1
    }
}
