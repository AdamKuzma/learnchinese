//
//  HSKProgressView.swift
//  LearnChinese
//

import SwiftData
import SwiftUI

struct HSKProgressView: View {
    @Query private var cards: [Flashcard]
    @Query private var progressRecords: [ItemProgress]

    private var snapshot: HSKProgressSnapshot {
        ProgressService.snapshot(cards: cards, progress: progressRecords)
    }

    var body: some View {
        List {
            ForEach(snapshot.levels) { level in
                NavigationLink {
                    HSKLevelDetailView(level: level.level)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HSK \(level.level)")
                            .font(.headline)
                        labeledBar(
                            title: "Vocabulary",
                            added: level.vocabAdded,
                            mastered: level.vocabMastered,
                            total: level.vocabTotal,
                            showsStars: true
                        )
                        labeledBar(
                            title: "Grammar",
                            added: level.grammarAdded,
                            mastered: level.grammarMastered,
                            total: level.grammarTotal
                        )
                    }
                    .padding(.vertical, 4)
                }
            }

            NavigationLink {
                HSKCustomDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom")
                        .font(.headline)
                    Text(customSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("HSK progress")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var customSummary: String {
        let custom = snapshot.custom
        if custom.added == 0 {
            return "No non-HSK flashcards"
        }
        return "\(custom.mastered) mastered · \(custom.learning) learning"
    }

    private func labeledBar(
        title: String,
        added: Int,
        mastered: Int,
        total: Int,
        showsStars: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                if showsStars {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text("\(mastered)")
                        .monospacedDigit()
                }
                Spacer()
                Text("\(added)/\(total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            ProgressView(value: total == 0 ? 0 : Double(added), total: Double(max(total, 1)))
            Text("\(mastered) mastered · \(added - mastered) learning")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct HSKLevelDetailView: View {
    let level: Int

    @Query private var cards: [Flashcard]
    @Query private var progressRecords: [ItemProgress]

    private var items: [TrackedItem] {
        ProgressService.trackedItems(
            level: level,
            cards: cards,
            progress: progressRecords
        )
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing in progress",
                    systemImage: "checkmark.circle",
                    description: Text("Add flashcards that match HSK \(level) vocabulary or grammar to see them here.")
                )
            } else {
                ForEach(items) { item in
                    TrackedItemRow(item: item)
                }
            }
        }
        .navigationTitle("HSK \(level)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HSKCustomDetailView: View {
    @Query private var cards: [Flashcard]
    @Query private var progressRecords: [ItemProgress]

    private var items: [TrackedItem] {
        ProgressService.trackedItems(
            level: nil,
            customOnly: true,
            cards: cards,
            progress: progressRecords
        )
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No custom words",
                    systemImage: "text.badge.plus",
                    description: Text("Words that are not in the HSK 3.0 lists show up here.")
                )
            } else {
                ForEach(items) { item in
                    TrackedItemRow(item: item)
                }
            }
        }
        .navigationTitle("Custom")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TrackedItemRow: View {
    let item: TrackedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title)
                    .font(.headline)
                Spacer()
                if item.kind == .grammar {
                    Text(item.status.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.status == .mastered ? .primary : .secondary)
                } else {
                    MasteryStars(
                        filled: MasteryCriteria.stars(
                            hasFlashcard: true,
                            lessonConfirmations: item.lessonConfirmations,
                            dailyMissionCompletions: item.dailyMissionCompletions
                        )
                    )
                }
            }
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(progressCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var progressCaption: String {
        "\(item.kind == .grammar ? "Grammar" : item.kind == .custom ? "Custom" : "Vocabulary") · \(item.lessonConfirmations)/\(MasteryCriteria.requiredLessonConfirmations) quiz · \(item.dailyMissionCompletions)/\(MasteryCriteria.requiredDailyMissionCompletions) missions"
    }
}
