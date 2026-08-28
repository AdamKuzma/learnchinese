//
//  HomeView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData
import Combine
import UIKit

struct HomeView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Flashcard]

    @State private var showQuiz = false
    @State private var showProfile = false
    @State private var profileImage: UIImage?

    var body: some View {
        List {
            Section {
                Text(greeting)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.appForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                    .accessibilityAddTraits(.isHeader)
            }
            .listRowInsets(EdgeInsets(top: 20, leading: 4, bottom: 8, trailing: 4))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            statusSection

            Section {
                NavigationLink {
                    ManageCardsView(kind: .vocabulary)
                } label: {
                    Label {
                        HStack(spacing: 6) {
                            Text("Vocabulary")
                            Text("\(vocabularyCards.count)")
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.closed.fill")
                    }
                }
            }
            .appListRowBackground()

            Section {
                NavigationLink {
                    ManageCardsView(kind: .grammar)
                } label: {
                    Label {
                        HStack(spacing: 6) {
                            Text("Grammar")
                            Text("\(grammarCards.count)")
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "text.book.closed.fill")
                    }
                }
            }
            .appListRowBackground()

            Section {
                NavigationLink {
                    DailyMissionView()
                } label: {
                    Label("Daily Mission", systemImage: "flag.fill")
                }
            }
            .appListRowBackground()

            Section {
                Button {
                    showQuiz = true
                } label: {
                    HStack {
                        Label("Start Lesson", systemImage: "play.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .disabled(!canStartQuiz)
            } footer: {
                if !canStartQuiz {
                    Text(quizDisabledReason)
                }
            }
            .appListRowBackground()
        }
        .appListChrome()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showProfile = true
                } label: {
                    ProfileAvatarImage(image: profileImage, size: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(profileImage: profileImage)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showQuiz) {
            NavigationStack {
                QuizView(cards: vocabularyCards)
            }
            .appScreenBackground()
        }
        .onAppear {
            blocker.refreshShieldState()
            loadProfilePhoto()
            Flashcard.capitalizeStoredVocabularyEnglish(in: modelContext)
        }
        .onChange(of: showProfile) { _, isShowing in
            if !isShowing {
                loadProfilePhoto()
            }
        }
    }

    private func loadProfilePhoto() {
        if let data = SharedStore.profilePhotoData {
            profileImage = UIImage(data: data)
        } else {
            profileImage = nil
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var vocabularyCards: [Flashcard] {
        cards.filter { $0.cardKind == .vocabulary }
    }

    private var grammarCards: [Flashcard] {
        cards.filter { $0.cardKind == .grammar }
    }

    private var canStartQuiz: Bool {
        vocabularyCards.count >= 4 && blocker.hasBlockedApps
    }

    private var quizDisabledReason: String {
        if !blocker.hasBlockedApps {
            return "Select at least one app to block first."
        }
        if vocabularyCards.count < 4 {
            return "Add at least 4 vocabulary words to start a quiz."
        }
        return ""
    }

    @ViewBuilder
    private var statusSection: some View {
        Section {
            StatusWithEnergyView()
        }
        .appListRowBackground()
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
                    .foregroundStyle(Color.appForeground)
                Button("Grant access") {
                    Task { await blocker.requestAuthorization() }
                }
            }
        } else if blocker.isUnlocked {
            UnlockCountdownView(unlockUntil: blocker.unlockUntil ?? .now, now: now)
        } else if blocker.isBlocking {
            Label("Apps are blocked", systemImage: "lock.fill")
                .foregroundStyle(Color.appForeground)
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
                .foregroundStyle(Color.appForeground)
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
