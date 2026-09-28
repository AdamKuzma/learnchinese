//
//  VocabStars.swift
//  LearnChinese
//

import Foundation

enum VocabStars {
    static let recallCountForOneStar = 5
    static let recallDaysForOneStar = 3
    static let missionCountForTwoStars = 2
    static let missionDaysForTwoStars = 2
    static let recallCountForThreeStars = 10
    static let missionCountForThreeStars = 5
    static let activitySpanDaysForThreeStars = 14

    static func count(
        recallCount: Int,
        recallDayCount: Int,
        missionCount: Int,
        missionDayCount: Int,
        activitySpanDays: Int
    ) -> Int {
        let hasOneStar =
            recallCount >= recallCountForOneStar &&
            recallDayCount >= recallDaysForOneStar
        let hasTwoStars =
            hasOneStar &&
            missionCount >= missionCountForTwoStars &&
            missionDayCount >= missionDaysForTwoStars
        let hasThreeStars =
            hasTwoStars &&
            recallCount >= recallCountForThreeStars &&
            missionCount >= missionCountForThreeStars &&
            activitySpanDays >= activitySpanDaysForThreeStars

        if hasThreeStars { return 3 }
        if hasTwoStars { return 2 }
        if hasOneStar { return 1 }
        return 0
    }

    static func count(for progress: ItemProgress?, calendar: Calendar = .current) -> Int {
        guard let progress else { return 0 }
        let span: Int
        if let first = progress.firstActivityAt, let last = progress.lastActivityAt {
            span = DayKeyStore.spanDays(from: first, to: last, calendar: calendar)
        } else {
            span = 0
        }
        return count(
            recallCount: progress.lessonConfirmations,
            recallDayCount: progress.recallDayKeys.count,
            missionCount: progress.dailyMissionCompletions,
            missionDayCount: progress.missionDayKeys.count,
            activitySpanDays: span
        )
    }

    static func needsMoreStars(for progress: ItemProgress?) -> Bool {
        count(for: progress) < 3
    }

    /// Missions still needed for the next star. Star 1 is recall-only, so 0-star words
    /// rank farther away than any 1-star or 2-star word a mission can actually finish.
    static func remainingMissionPracticeToNextStar(
        starCount: Int,
        missionCount: Int,
        missionDayCount: Int
    ) -> Int {
        switch starCount {
        case 3:
            return 8
        case 2:
            return max(0, missionCountForThreeStars - missionCount)
        case 1:
            return max(
                max(0, missionCountForTwoStars - missionCount),
                max(0, missionDaysForTwoStars - missionDayCount)
            )
        default:
            return missionCountForTwoStars + 3
        }
    }

    static func remainingMissionPractice(for progress: ItemProgress?) -> Int {
        remainingMissionPracticeToNextStar(
            starCount: count(for: progress),
            missionCount: progress?.dailyMissionCompletions ?? 0,
            missionDayCount: progress?.missionDayKeys.count ?? 0
        )
    }

    static func missionPickWeight(remainingPractice: Int, starCount: Int) -> Double {
        if starCount >= 3 { return 0.35 }
        return 12.0 / (1.0 + Double(max(0, remainingPractice)))
    }
}
