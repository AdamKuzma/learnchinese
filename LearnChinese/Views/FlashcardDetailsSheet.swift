//
//  FlashcardDetailsSheet.swift
//  LearnChinese
//

import SwiftData
import SwiftUI

struct FlashcardDetailsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Bindable var card: Flashcard
    @Query private var allCards: [Flashcard]

    @State private var isGeneratingLexicon = false
    @State private var isGeneratingSentences = false
    @State private var errorMessage: String?
    @State private var savedVocabularyHanzi: Set<String> = []

    private let service = OpenAIFlashcardDetailsService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppLabeledBlock(title: "Word") {
                        wordCard
                    }

                    AppLabeledBlock(title: "Character breakdown") {
                        characterBreakdownCard
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(
                            title: "Example sentences",
                            isLoading: isGeneratingSentences && !card.exampleSentences.isEmpty,
                            action: { Task { await refreshSentences() } }
                        )
                        .padding(.horizontal, 4)

                        exampleSentencesCard
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appRaisedCard()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appRaisedCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .appScreenBackground()
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Done")
                }
            }
            .task {
                await generateMissingDetails()
            }
        }
    }

    private var wordCard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.hanzi)
                    .font(.largeTitle.weight(.semibold))
                if !card.pinyin.isEmpty {
                    Text(card.pinyin)
                        .foregroundStyle(.secondary)
                }
                Text(card.displayEnglish)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isGeneratingLexicon && card.partsOfSpeech.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if !card.partsOfSpeech.isEmpty {
                VStack(alignment: .trailing, spacing: 6) {
                    ForEach(Array(card.partsOfSpeech.enumerated()), id: \.offset) { _, part in
                        Text(PartOfSpeechLabel.displayName(for: part))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.appForeground.opacity(0.08))
                            )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var characterBreakdownCard: some View {
        if isGeneratingLexicon && card.characterBreakdown.isEmpty {
            centeredSpinner
        } else if card.characterBreakdown.isEmpty {
            Text("No character breakdown yet.")
                .foregroundStyle(.secondary)
        } else {
            characterBreakdownRow(card.characterBreakdown)
        }
    }

    @ViewBuilder
    private var exampleSentencesCard: some View {
        if isGeneratingSentences && card.exampleSentences.isEmpty {
            centeredSpinner
        } else if card.exampleSentences.isEmpty {
            Text("No example sentences yet.")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(card.exampleSentences.enumerated()), id: \.offset) { index, sentence in
                    if index > 0 {
                        Color.appSecondaryBorder
                            .frame(height: 0.5)
                    }
                    exampleSentenceRow(sentence)
                }
            }
        }
    }

    private func exampleSentenceRow(_ sentence: FlashcardExampleSentence) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TappableChineseSentence(
                words: sentenceWords(sentence),
                font: .title3,
                savedHanzi: savedVocabulary,
                onToggle: toggleWordInFlashcards,
                lineSpacing: 1,
                wordVerticalPadding: 0
            )

            if !sentence.english.isEmpty {
                Text(sentence.english)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sentenceWords(_ sentence: FlashcardExampleSentence) -> [MissionWord] {
        let groups = ExampleSentenceWords.grouped(tokens: sentence.tokens)
        let words = groups.isEmpty
            ? ChineseWordSegmenter.segment(sentence.chinese)
            : groups.map(\.word)
        return words.map(resolvedWord)
    }

    private func resolvedWord(_ word: MissionWord) -> MissionWord {
        let hanzi = word.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        let known = card.hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hanzi == known else { return word }
        return MissionWord(
            hanzi: card.hanzi,
            pinyin: card.pinyin.isEmpty ? word.pinyin : card.pinyin,
            english: card.displayEnglish.isEmpty ? word.english : card.displayEnglish
        )
    }

    private func characterBreakdownRow(_ items: [FlashcardCharacterMeaning]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 6) {
                    Text(item.pinyin.isEmpty ? " " : item.pinyin)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(item.hanzi)
                        .font(.system(size: 40, weight: .medium))
                    Text(item.meaning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var centeredSpinner: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func sectionHeader(title: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            AppSectionHeader(title: title)
            Spacer()
            Button(action: action) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .imageScale(.small)
                }
            }
            .disabled(isLoading)
            .accessibilityLabel("Regenerate \(title)")
        }
    }

    @MainActor
    private func generateMissingDetails() async {
        errorMessage = nil
        async let syntax: Void = refreshSyntaxIfNeeded()
        async let sentences: Void = refreshSentencesIfNeeded()
        _ = await (syntax, sentences)
    }

    @MainActor
    private func refreshSyntaxIfNeeded() async {
        guard !card.hasGeneratedWordSyntax else { return }
        await refreshSyntax()
    }

    @MainActor
    private func refreshSentencesIfNeeded() async {
        guard !card.hasGeneratedExampleSentences else { return }
        await refreshSentences(clearExistingError: false)
    }

    @MainActor
    private func refreshSyntax() async {
        guard !isGeneratingLexicon else { return }
        isGeneratingLexicon = true

        do {
            let input = generationInput
            let syntax = try await service.generateWordSyntax(
                hanzi: input.hanzi,
                pinyin: input.pinyin,
                english: input.english
            )
            card.applyWordSyntax(syntax)
            try context.save()
        } catch {
            presentError(error)
        }

        isGeneratingLexicon = false
    }

    @MainActor
    private func refreshSentences(clearExistingError: Bool = true) async {
        guard !isGeneratingSentences else { return }
        if clearExistingError {
            errorMessage = nil
        }
        isGeneratingSentences = true

        do {
            let input = generationInput
            let sentences = try await service.generateExampleSentences(
                hanzi: input.hanzi,
                pinyin: input.pinyin,
                english: input.english
            )
            card.applyExampleSentences(sentences)
            try context.save()
        } catch {
            presentError(error)
        }

        isGeneratingSentences = false
    }

    private func presentError(_ error: Error) {
        let message = error.localizedDescription
        if let errorMessage, !errorMessage.contains(message) {
            self.errorMessage = errorMessage + "\n" + message
        } else {
            errorMessage = message
        }
    }

    private var savedVocabulary: Set<String> {
        let fromStore = Set(
            allCards
                .filter { $0.cardKind == .vocabulary }
                .map { $0.hanzi.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        return fromStore.union(savedVocabularyHanzi)
    }

    private func normalizedHanzi(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func existingFlashcard(for hanzi: String) -> Flashcard? {
        let target = normalizedHanzi(hanzi)
        return allCards.first { normalizedHanzi($0.hanzi) == target && $0.cardKind == .vocabulary }
    }

    private func toggleWordInFlashcards(_ word: MissionWord) {
        let hanzi = normalizedHanzi(word.hanzi)
        guard !hanzi.isEmpty else { return }
        if hanzi == normalizedHanzi(card.hanzi), card.cardKind == .vocabulary {
            return
        }

        if savedVocabulary.contains(hanzi) {
            if let existing = existingFlashcard(for: hanzi) {
                context.delete(existing)
                try? context.save()
            }
            savedVocabularyHanzi.remove(hanzi)
            return
        }

        AppHaptics.addedItem()
        Task { await saveFlashcard(word) }
    }

    @MainActor
    private func saveFlashcard(_ word: MissionWord) async {
        let hanzi = normalizedHanzi(word.hanzi)
        guard existingFlashcard(for: hanzi) == nil else {
            savedVocabularyHanzi.insert(hanzi)
            return
        }

        let newCard = Flashcard(
            hanzi: hanzi,
            pinyin: word.pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            english: word.english.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(newCard)
        try? context.save()
        savedVocabularyHanzi.insert(hanzi)

        do {
            let details = try await service.generateAll(
                hanzi: newCard.hanzi,
                pinyin: newCard.pinyin,
                english: newCard.english
            )
            guard let live = existingFlashcard(for: hanzi) else { return }
            live.exampleChinese = details.sentence.chinese
            live.exampleEnglish = details.sentence.english
            live.memoryHintChinese = details.memoryHint.chinese
            live.memoryHintEnglish = details.memoryHint.english
            live.memoryHint = nil
            live.detailsGeneratedAt = .now
            try? context.save()
        } catch {
            // Card still saves; details can be generated later from the quiz sheet.
        }
    }

    private var generationInput: GenerationInput {
        GenerationInput(
            hanzi: card.hanzi,
            pinyin: card.pinyin,
            english: card.english
        )
    }
}

private struct GenerationInput {
    let hanzi: String
    let pinyin: String
    let english: String
}
