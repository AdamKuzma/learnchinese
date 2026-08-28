//
//  PullToRevealSearch.swift
//  LearnChinese
//

import Foundation

enum SearchRevealScrollPhase: Equatable {
    case userDragging
    case coasting
    case idle
}

struct PullToRevealSearchState: Equatable {
    static let barHeight: CGFloat = 52
    static let pinThreshold: CGFloat = 28
    static let hideThreshold: CGFloat = 12

    var revealedHeight: CGFloat = 0
    var isExpanded = false

    var displayHeight: CGFloat {
        isExpanded ? Self.barHeight : revealedHeight
    }

    mutating func expand() {
        isExpanded = true
        revealedHeight = Self.barHeight
    }

    mutating func handleScroll(
        offsetFromTop: CGFloat,
        phase: SearchRevealScrollPhase,
        isLockedOpen: Bool
    ) {
        if isLockedOpen {
            expand()
            return
        }

        if isExpanded {
            if phase == .userDragging, offsetFromTop > Self.hideThreshold {
                isExpanded = false
                revealedHeight = 0
            }
            return
        }

        guard phase == .userDragging else { return }

        if offsetFromTop < 0 {
            revealedHeight = min(Self.barHeight, -offsetFromTop)
        } else {
            revealedHeight = 0
        }
    }

    mutating func handleDragEnded(isLockedOpen: Bool) {
        if isLockedOpen {
            expand()
            return
        }
        guard !isExpanded else { return }

        if revealedHeight >= Self.pinThreshold {
            expand()
        } else {
            revealedHeight = 0
        }
    }
}
