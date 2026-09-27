//
//  DailyActivity.swift
//  LearnChinese
//

import Foundation
import SwiftData

@Model
final class DailyActivity {
    @Attribute(.unique) var dayStart: Date
    var count: Int

    init(dayStart: Date, count: Int) {
        self.dayStart = dayStart
        self.count = count
    }
}
