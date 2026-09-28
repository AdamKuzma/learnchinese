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
                VStack(alignment: .leading, spacing: 8) {
                    Text(greeting)
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.appForeground)
                        .accessibilityAddTraits(.isHeader)

                    BlockStatusLine()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            }
            .listRowInsets(EdgeInsets(top: 20, leading: 4, bottom: 8, trailing: 4))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

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
            Flashcard.restoreSavedKinds(in: modelContext)
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
}

private struct BlockStatusLine: View {
    @EnvironmentObject private var blocker: AppBlocker
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                Text(statusText)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !blocker.isAuthorized {
                Button("Grant access") {
                    Task { await blocker.requestAuthorization() }
                }
                .font(.subheadline)
            }
        }
        .onReceive(timer) { now = $0 }
    }

    private var iconName: String {
        if !blocker.isAuthorized {
            return "exclamationmark.triangle.fill"
        }
        if blocker.isUnlocked {
            return "lock.open"
        }
        if blocker.isBlocking {
            return "lock.fill"
        }
        return "lock.open"
    }

    private var statusText: String {
        if !blocker.isAuthorized {
            return "Screen Time access not granted"
        }
        if blocker.isUnlocked {
            let minutes = max(0, Int(blocker.remainingEnergyMinutes(at: now).rounded(.down)))
            return "Apps unlocked for \(minutes)min"
        }
        if blocker.isBlocking {
            return "Apps locked"
        }
        return "No apps blocked"
    }
}
