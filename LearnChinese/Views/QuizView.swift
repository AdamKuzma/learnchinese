//
//  QuizView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData

struct QuizView: View {
    let cards: [Flashcard]

    @EnvironmentObject private var blocker: AppBlocker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var progressRecords: [ItemProgress]

    @State private var question: Question?
    @State private var correctCount = 0
    @State private var selected: String?
    @State private var finished = false
    @State private var quizMode: SessionMode = .standard
    @State private var questionTypeMode: QuestionTypeMode = .chineseToEnglish
    @State private var detailCard: Flashcard?
    @State private var energyGranted = 0
    @State private var sessionKeys: Set<String> = []
    @State private var lastPromptKey: String?

    private var required: Int { quizMode.requiredCorrect }

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(correctCount), total: Double(required)) {
                Text("\(correctCount) / \(required) correct")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if finished {
                finishedView
            } else if let question {
                questionView(question)
            } else {
                ContentUnavailableView(
                    "Not enough vocabulary",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Add at least 4 vocabulary words to start a quiz.")
                )
            }

            Spacer()
        }
        .padding(.top)
        .appScreenBackground()
        .navigationTitle("Lesson")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
        .onAppear {
            quizMode = blocker.sessionMode
            questionTypeMode = blocker.questionTypeMode
            nextQuestion()
        }
        .sheet(item: $detailCard) { card in
            FlashcardDetailsSheet(card: card)
        }
    }

    @ViewBuilder
    private func questionView(_ question: Question) -> some View {
        VStack(spacing: 8) {
            if question.promptIsChinese {
                Button {
                    detailCard = question.promptCard
                } label: {
                    Text(question.promptPrimary)
                        .font(.system(size: 64, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens word details, character breakdown, and example sentences")
            } else {
                Text(question.promptPrimary)
                    .font(.system(size: 44, weight: .semibold))
            }
            if let secondary = question.promptSecondary {
                Text(secondary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical)

        Text(question.instruction)
            .font(.headline)

        VStack(spacing: 12) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    answer(option, for: question)
                } label: {
                    Text(option)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(Color.appForeground)
                        .background(optionBackground(for: option, question: question))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                                .stroke(Color.appSecondaryBorder, lineWidth: 0.5)
                        }
                        .clipShape(
                            RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                        )
                }
                .disabled(selected != nil)
            }
        }
        .padding(.horizontal)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.appForeground)
            VStack(spacing: 6) {
                Text("Lesson complete")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.appForeground)
                Text(energyGranted > 0 ? "+\(energyGranted) min energy" : "Energy is full")
                    .font(.subheadline)
                    .foregroundStyle(Color.appMutedText)
            }
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(Color.appForeground)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appSecondaryBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                            .stroke(Color.appSecondaryBorder, lineWidth: 0.5)
                    }
                    .clipShape(
                        RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                    )
                    .contentShape(
                        RoundedRectangle(cornerRadius: AppChrome.containerCornerRadius, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    private func optionBackground(for option: String, question: Question) -> Color {
        guard let selected else { return Color.appSecondaryBackground }
        if option == question.answer {
            return Color.appSecondaryBackground.opacity(0.55)
        }
        if option == selected {
            return Color.appSecondaryBackground.opacity(0.7)
        }
        return Color.appSecondaryBackground
    }

    private func answer(_ option: String, for question: Question) {
        guard selected == nil else { return }
        selected = option

        if option == question.answer {
            correctCount += 1
            ProgressService.recordLessonConfirmation(hanzi: question.promptCard.hanzi, in: modelContext)
        }

        let completed = correctCount >= required
        DispatchQueue.main.asyncAfter(deadline: .now() + (completed ? 0.45 : 0.8)) {
            if completed {
                showLessonComplete()
            } else {
                nextQuestion()
            }
        }
    }

    private func showLessonComplete() {
        energyGranted = quizMode.unlockMinutes
        finished = true
        SharedStore.recordActivity(.lesson)
        Task { @MainActor in
            energyGranted = blocker.addEnergy(minutes: quizMode.unlockMinutes)
        }
    }

    private func nextQuestion() {
        selected = nil
        guard let prompt = CardPicker.pick(
            from: cards,
            progress: progressRecords,
            sessionKeys: sessionKeys,
            lastKey: lastPromptKey
        ) else {
            question = nil
            return
        }

        let key = HanziNormalizer.normalize(prompt.hanzi)
        sessionKeys.insert(key)
        lastPromptKey = key
        ProgressService.markShown(hanzi: prompt.hanzi, in: modelContext)
        question = Question.make(from: cards, prompt: prompt, mode: questionTypeMode)
    }
}

private struct Question {
    let promptPrimary: String
    let promptSecondary: String?
    let instruction: String
    let options: [String]
    let answer: String
    let promptCard: Flashcard
    let promptIsChinese: Bool

    static func make(from cards: [Flashcard], prompt: Flashcard, mode: QuestionTypeMode) -> Question? {
        let resolvedMode: QuestionTypeMode
        switch mode {
        case .mixed:
            resolvedMode = Bool.random() ? .chineseToEnglish : .englishToChinese
        default:
            resolvedMode = mode
        }

        switch resolvedMode {
        case .chineseToEnglish:
            let pool = cards.map(\.displayEnglish)
            guard let options = buildOptions(correct: prompt.displayEnglish, pool: pool) else { return nil }
            return Question(
                promptPrimary: prompt.hanzi,
                promptSecondary: prompt.pinyin.isEmpty ? nil : prompt.pinyin,
                instruction: "What does this mean?",
                options: options,
                answer: prompt.displayEnglish,
                promptCard: prompt,
                promptIsChinese: true
            )
        case .englishToChinese:
            let correct = chineseOptionText(for: prompt)
            let pool = cards.map(chineseOptionText(for:))
            guard let options = buildOptions(correct: correct, pool: pool) else { return nil }
            return Question(
                promptPrimary: prompt.displayEnglish,
                promptSecondary: nil,
                instruction: "Choose the Chinese translation.",
                options: options,
                answer: correct,
                promptCard: prompt,
                promptIsChinese: false
            )
        case .mixed:
            return nil
        }
    }

    private static func buildOptions(correct: String, pool: [String]) -> [String]? {
        let uniquePool = Array(Set(pool))
        guard uniquePool.count >= 4 else { return nil }

        var distractors = Set<String>()
        for candidate in uniquePool.shuffled() where candidate != correct {
            if distractors.count >= 3 { break }
            distractors.insert(candidate)
        }
        guard distractors.count == 3 else { return nil }
        return (Array(distractors) + [correct]).shuffled()
    }

    private static func chineseOptionText(for card: Flashcard) -> String {
        if card.pinyin.isEmpty {
            return card.hanzi
        }
        return "\(card.hanzi) (\(card.pinyin))"
    }
}
