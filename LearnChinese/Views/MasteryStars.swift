//
//  MasteryStars.swift
//  LearnChinese
//

import SwiftUI

struct MasteryStars: View {
    let filled: Int

    private var total: Int { MasteryCriteria.displayedStars }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { index in
                Image(systemName: index < filled ? "star.fill" : "star")
                    .foregroundStyle(index < filled ? Color.primary : Color.secondary)
            }
        }
        .font(.caption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(min(max(filled, 0), total)) of \(total) stars")
    }
}
