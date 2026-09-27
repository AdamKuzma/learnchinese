//
//  HomeView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @Query private var cards: [Flashcard]
    @Query private var progressRecords: [ItemProgress]
    @Query private var activities: [DailyActivity]

    @State private var showQuiz = false

    var body: some View {
        List {
            statusSection

            Section("Streak") {
                StreakSectionView(activities: activities)
            }

            progressSection

            Section {
                NavigationLink {
                    ManageCardsView()
                } label: {
                    Label("Manage flashcards (\(cards.count))", systemImage: "rectangle.on.rectangle")
                }
            }

            Section {
                NavigationLink {
                    DailyMissionView()
                } label: {
                    Label("Daily Mission", systemImage: "flag.fill")
                }
            }

            Section("Lesson settings") {
                Picker("Mode", selection: sessionModeBinding) {
                    ForEach(SessionMode.allCases) { mode in
                        Text("\(mode.title): \(mode.summary)").tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Picker("Question type", selection: questionTypeBinding) {
                    ForEach(QuestionTypeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

            }

            Section {
                Button {
                    showQuiz = true
                } label: {
                    Label("Unlock with \(blocker.sessionMode.requiredCorrect) flashcards", systemImage: "lock.open.fill")
                }
                .disabled(!canStartQuiz)

                if !canStartQuiz {
                    Text(quizDisabledReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Learn Chinese")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showQuiz) {
            NavigationStack {
                QuizView(cards: cards)
            }
        }
        .onAppear { blocker.refreshShieldState() }
    }

    private var canStartQuiz: Bool {
        cards.count >= 4 && blocker.hasBlockedApps
    }

    private var sessionModeBinding: Binding<SessionMode> {
        Binding(
            get: { blocker.sessionMode },
            set: { blocker.updateSessionMode($0) }
        )
    }

    private var questionTypeBinding: Binding<QuestionTypeMode> {
        Binding(
            get: { blocker.questionTypeMode },
            set: { blocker.updateQuestionTypeMode($0) }
        )
    }

    private var quizDisabledReason: String {
        if !blocker.hasBlockedApps {
            return "Select at least one app to block first."
        }
        if cards.count < 4 {
            return "Add at least 4 flashcards to start a quiz."
        }
        return ""
    }

    @ViewBuilder
    private var progressSection: some View {
        let snapshot = ProgressService.snapshot(cards: cards, progress: progressRecords)
        let summary = snapshot.summary(in: blocker.hskRange)
        Section("HSK progress") {
            NavigationLink {
                HSKProgressView()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text(blocker.hskRange.title)
                        .font(.headline)
                    labeledBar(title: "Vocabulary", added: summary.vocabAdded, total: summary.vocabTotal)
                    labeledBar(title: "Grammar", added: summary.grammarAdded, total: summary.grammarTotal)
                    if snapshot.custom.added > 0 {
                        Text("Custom \(snapshot.custom.added)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func labeledBar(title: String, added: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(added)/\(total)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            ProgressView(value: total == 0 ? 0 : Double(added), total: Double(max(total, 1)))
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            StatusWithEnergyView()
        }
    }
}

private struct StatusWithEnergyView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusLabel
            EnergyBarView(remainingMinutes: blocker.remainingEnergyMinutes(at: now))
        }
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if !blocker.isAuthorized {
            VStack(alignment: .leading, spacing: 8) {
                Label("Screen Time access not granted", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.primary)
                Button("Grant access") {
                    Task { await blocker.requestAuthorization() }
                }
            }
        } else if blocker.isUnlocked {
            UnlockCountdownView(unlockUntil: blocker.unlockUntil ?? .now, now: now)
        } else if blocker.isBlocking {
            Label("Apps are blocked", systemImage: "lock.fill")
                .foregroundStyle(.primary)
        } else {
            Label("No apps blocked", systemImage: "lock.open")
                .foregroundStyle(.secondary)
        }
    }
}

private struct EnergyBarView: View {
    let remainingMinutes: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Energy")
                Spacer()
                Text("\(displayMinutes) / \(Energy.capMinutes) min")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ProgressView(value: remainingMinutes, total: Double(Energy.capMinutes))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Energy \(displayMinutes) of \(Energy.capMinutes) minutes")
    }

    private var displayMinutes: Int {
        min(Energy.capMinutes, max(0, Int(remainingMinutes.rounded(.down))))
    }
}

private struct UnlockCountdownView: View {
    let unlockUntil: Date
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Apps unlocked", systemImage: "lock.open.fill")
                .foregroundStyle(.primary)
            Text("Re-blocks in \(remainingText)")
                .font(.title2.monospacedDigit().weight(.semibold))
        }
    }

    private var remainingText: String {
        let remaining = max(0, Int(unlockUntil.timeIntervalSince(now)))
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
