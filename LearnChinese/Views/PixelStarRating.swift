//
//  PixelStarRating.swift
//  LearnChinese
//

import SwiftUI

struct PixelStarRating: View {
    var count: Int

    private let slotCount = 3

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<max(0, min(count, slotCount)), id: \.self) { _ in
                PixelStar()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(count == 1 ? "1 star" : "\(count) stars")
    }
}

private struct PixelStar: View {
    private static let pattern: [[Bool]] = [
        [false, false, true, false, false],
        [false, true, true, true, false],
        [true, true, true, true, true],
        [false, true, true, true, false],
        [true, false, true, false, true]
    ]

    private let pixel: CGFloat = 1.5
    private let gap: CGFloat = 0.4

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<Self.pattern.count, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<Self.pattern[row].count, id: \.self) { column in
                        Rectangle()
                            .fill(Self.pattern[row][column] ? Color.appForeground : Color.clear)
                            .frame(width: pixel, height: pixel)
                    }
                }
            }
        }
    }
}
