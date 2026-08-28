//
//  ItemProgress.swift
//  LearnChinese
//

import Foundation
import SwiftData

@Model
final class ItemProgress {
    @Attribute(.unique) var normalizedHanzi: String
    var lessonConfirmations: Int
    var dailyMissionCompletions: Int
    var lastShownAt: Date?

    init(
        normalizedHanzi: String,
        lessonConfirmations: Int = 0,
        dailyMissionCompletions: Int = 0,
        lastShownAt: Date? = nil
    ) {
        self.normalizedHanzi = HanziNormalizer.normalize(normalizedHanzi)
        self.lessonConfirmations = lessonConfirmations
        self.dailyMissionCompletions = dailyMissionCompletions
        self.lastShownAt = lastShownAt
    }
}
