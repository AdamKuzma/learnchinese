//
//  DailyMissionView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData
import UIKit

struct DailyMissionView: View {
    private enum Phase {
        case generating
        case playing
        case evaluating
        case result
        case failed
    }

    @State private var phase: Phase = .generating
    @State private var mission: DailyMission?
    @State private var evaluation: DailyMissionEvaluation?
    @State private var userResponse = ""
    @State private var errorMessage: String?
    @State private var showEnglish = false
    @State private var showSituationPinyin = false
    @State private var showTaskPinyin = false
    @State private var energyGranted = 0
    @State private var showReplaceFlashcard = false
    @State private var isSavingFlashcard = false
    @State private var savedFlashcardHanzi: String?

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Flashcard]
    @EnvironmentObject private var blocker: AppBlocker
    private let service = OpenAIFlashcardDetailsService.shared

    var body: some View {
        Form {
            switch phase {
            case .generating:
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Creating your mission…")
                        Spacer()
                    }
                    .padding(.vertical)
                }
            case .playing, .evaluating:
                if let mission {
                    missionSections(mission)
                    replySection
                }
            case .result:
                if let mission {
                    missionSections(mission)
                }
                if let evaluation {
                    resultSections(evaluation)
                }
            case .failed:
                Section {
                    Text(errorMessage ?? "Couldn't create a mission.")
                        .foregroundStyle(.red)
                    Button("Try again") {
                        Task { await startMission() }
                    }
                }
            }

            if let errorMessage, phase == .playing || phase == .evaluating || phase == .result {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Daily Mission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if mission != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showEnglish ? "中文" : "EN") {
                        showEnglish.toggle()
                    }
                    .accessibilityLabel(showEnglish ? "Show Chinese" : "Show English")
                }
            }
        }
        .task {
            await startMission()
        }
        .confirmationDialog(
            "Flashcard already exists",
            isPresented: $showReplaceFlashcard,
            titleVisibility: .visible
        ) {
            Button("Replace") {
                Task { await saveFlashcard(replacingExisting: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let hanzi = mission?.hanzi {
                Text("You already have a flashcard for \(hanzi). Replace it with this pinyin and meaning?")
            } else {
                Text("You already have a flashcard for this word. Replace it with this pinyin and meaning?")
            }
        }
    }

    @ViewBuilder
    private func missionSections(_ mission: DailyMission) -> some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mission.hanzi)
                        .font(.largeTitle.weight(.semibold))
                    if !mission.pinyin.isEmpty {
                        Text(mission.pinyin)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(mission.meaning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Copy") {
                        UIPasteboard.general.string = mission.hanzi
                    }
                }

                Button {
                    addTargetWordToFlashcards()
                } label: {
                    if isSavingFlashcard {
                        ProgressView()
                    } else {
                        Image(systemName: savedFlashcardHanzi == normalizedHanzi(mission.hanzi) ? "checkmark.circle.fill" : "plus.circle")
                    }
                }
                .font(.title2)
                .disabled(isSavingFlashcard)
                .accessibilityLabel(
                    savedFlashcardHanzi == normalizedHanzi(mission.hanzi)
                        ? "Flashcard saved"
                        : "Add to flashcards"
                )
            }
        } header: {
            Text("Target word")
        }

        Section("Situation") {
            copyableText(
                display: showEnglish ? mission.situationEnglish : mission.situationChinese,
                copyText: showEnglish ? mission.situationEnglish : mission.situationChinese,
                pinyin: mission.situationPinyin,
                showPinyin: $showSituationPinyin,
                font: showEnglish ? .body : .headline
            )
        }

        Section("Mission") {
            copyableText(
                display: showEnglish ? mission.taskEnglish : mission.taskChinese,
                copyText: showEnglish ? mission.taskEnglish : mission.taskChinese,
                pinyin: mission.taskPinyin,
                showPinyin: $showTaskPinyin,
                font: showEnglish ? .body : .headline
            )
        }
    }

    private func copyableText(
        display: String,
        copyText: String,
        pinyin: String,
        showPinyin: Binding<Bool>,
        font: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(display)
                .font(font)
            if showPinyin.wrappedValue, !pinyin.isEmpty {
                Text(pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") {
                UIPasteboard.general.string = copyText
            }
            if !pinyin.isEmpty {
                Button(showPinyin.wrappedValue ? "Hide Pinyin" : "Show Pinyin") {
                    showPinyin.wrappedValue.toggle()
                }
            }
        }
    }

    private var replySection: some View {
        Section("Your reply") {
            TextField("Write in Chinese", text: $userResponse, axis: .vertical)
                .lineLimit(3...8)
                .disabled(phase == .evaluating)

            if phase == .evaluating {
                HStack {
                    Spacer()
                    ProgressView("Checking your reply…")
                    Spacer()
                }
            } else {
                Button("Submit") {
                    Task { await submitReply() }
                }
                .disabled(userResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private func resultSections(_ evaluation: DailyMissionEvaluation) -> some View {
        Section("Result") {
            LabeledContent("Mission success", value: evaluation.success ? "Yes" : "No")
            LabeledContent("Meaning", value: "\(evaluation.meaning)/5")
            LabeledContent("Grammar", value: "\(evaluation.grammar)/5")
            LabeledContent("Naturalness", value: "\(evaluation.naturalness)/5")
            LabeledContent(
                "Target word used correctly",
                value: evaluation.targetWordUsedCorrectly ? "Yes" : "No"
            )
            if evaluation.success {
                LabeledContent("Energy", value: "+\(energyGranted) min")
            }
        }

        Section("Feedback") {
            Text(evaluation.feedback)
        }

        if !userResponse.isEmpty {
            Section("Your reply") {
                Text(userResponse)
                    .textSelection(.enabled)
            }
        }

        Section("A more natural version") {
            Text(evaluation.naturalChinese)
                .font(.title3)
                .textSelection(.enabled)
        }

        Section {
            Button("New mission") {
                Task { await startMission() }
            }
        }
    }

    @MainActor
    private func startMission() async {
        errorMessage = nil
        evaluation = nil
        energyGranted = 0
        savedFlashcardHanzi = nil
        userResponse = ""
        mission = nil
        showEnglish = false
        showSituationPinyin = false
        showTaskPinyin = false
        phase = .generating

        do {
            let generated = try await service.generateMission(range: SharedStore.hskRange)
            mission = generated
            phase = .playing
        } catch {
            phase = .failed
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func submitReply() async {
        guard let mission else { return }
        let reply = userResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { return }

        errorMessage = nil
        phase = .evaluating

        do {
            let result = try await service.evaluate(mission: mission, userChinese: reply)
            if result.success {
                energyGranted = blocker.addEnergy(minutes: Energy.dailyMissionReward)
            }
            evaluation = result
            phase = .result
        } catch {
            phase = .playing
            errorMessage = error.localizedDescription
        }
    }

    private func normalizedHanzi(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func existingFlashcard(for hanzi: String) -> Flashcard? {
        let target = normalizedHanzi(hanzi)
        return cards.first { normalizedHanzi($0.hanzi) == target }
    }

    private func addTargetWordToFlashcards() {
        guard let mission, !isSavingFlashcard else { return }
        if existingFlashcard(for: mission.hanzi) != nil {
            showReplaceFlashcard = true
        } else {
            Task { await saveFlashcard(replacingExisting: false) }
        }
    }

    @MainActor
    private func saveFlashcard(replacingExisting: Bool) async {
        guard let mission, !isSavingFlashcard else { return }
        isSavingFlashcard = true

        let hanzi = normalizedHanzi(mission.hanzi)
        let pinyin = mission.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        let english = mission.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let card: Flashcard

        if replacingExisting, let existing = existingFlashcard(for: hanzi) {
            existing.hanzi = hanzi
            existing.pinyin = pinyin
            existing.english = english
            existing.exampleChinese = nil
            existing.exampleEnglish = nil
            existing.memoryHint = nil
            existing.memoryHintChinese = nil
            existing.memoryHintEnglish = nil
            existing.detailsGeneratedAt = nil
            card = existing
        } else if let existing = existingFlashcard(for: hanzi) {
            isSavingFlashcard = false
            showReplaceFlashcard = true
            return
        } else {
            card = Flashcard(hanzi: hanzi, pinyin: pinyin, english: english)
            modelContext.insert(card)
        }

        do {
            let details = try await OpenAIFlashcardDetailsService.shared.generateAll(
                hanzi: card.hanzi,
                pinyin: card.pinyin,
                english: card.english
            )
            card.exampleChinese = details.sentence.chinese
            card.exampleEnglish = details.sentence.english
            card.memoryHintChinese = details.memoryHint.chinese
            card.memoryHintEnglish = details.memoryHint.english
            card.memoryHint = nil
            card.detailsGeneratedAt = .now
        } catch {
            // Card still saves; details can be generated later from the quiz sheet.
        }

        try? modelContext.save()
        savedFlashcardHanzi = hanzi
        isSavingFlashcard = false
    }
}
