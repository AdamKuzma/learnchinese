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

    @State private var isGeneratingSentence = false
    @State private var isGeneratingMemoryHint = false
    @State private var errorMessage: String?

    private let service = OpenAIFlashcardDetailsService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.hanzi)
                            .font(.largeTitle.weight(.semibold))
                        if !card.pinyin.isEmpty {
                            Text(card.pinyin)
                                .foregroundStyle(.secondary)
                        }
                        Text(card.english)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section {
                    if isGeneratingSentence && !card.hasGeneratedSentence {
                        centeredSpinner
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.exampleChinese ?? "No example sentence yet.")
                                .font(.headline)
                            Text(card.exampleEnglish ?? "")
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } header: {
                    sectionHeader(
                        title: "Example sentence",
                        isLoading: isGeneratingSentence,
                        action: { Task { await refreshSentence() } }
                    )
                }

                Section {
                    if isGeneratingMemoryHint && !card.hasGeneratedMemoryHint {
                        centeredSpinner
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.memoryHintChinese ?? card.memoryHint ?? "No memory hint yet.")
                                .font(.headline)
                            Text(card.memoryHintEnglish ?? legacyMemoryHintEnglish)
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } header: {
                    sectionHeader(
                        title: "Memory hint",
                        isLoading: isGeneratingMemoryHint,
                        action: { Task { await refreshMemoryHint() } }
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await generateMissingDetails()
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
            Text(title)
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
        guard !card.hasGeneratedDetails else { return }

        if !card.hasGeneratedSentence && !card.hasGeneratedMemoryHint {
            await refreshAll()
            return
        }

        if !card.hasGeneratedSentence {
            await refreshSentence()
        }
        if !card.hasGeneratedMemoryHint {
            await refreshMemoryHint()
        }
    }

    @MainActor
    private func refreshAll() async {
        guard !isGeneratingSentence && !isGeneratingMemoryHint else { return }
        errorMessage = nil
        isGeneratingSentence = true
        isGeneratingMemoryHint = true

        do {
            let input = generationInput
            let details = try await service.generateAll(
                hanzi: input.hanzi,
                pinyin: input.pinyin,
                english: input.english
            )
            card.exampleChinese = details.sentence.chinese
            card.exampleEnglish = details.sentence.english
            card.memoryHintChinese = details.memoryHint.chinese
            card.memoryHintEnglish = details.memoryHint.english
            card.memoryHint = nil
            card.detailsGeneratedAt = .now
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingSentence = false
        isGeneratingMemoryHint = false
    }

    @MainActor
    private func refreshSentence() async {
        guard !isGeneratingSentence else { return }
        errorMessage = nil
        isGeneratingSentence = true

        do {
            let input = generationInput
            let sentence = try await service.generateSentence(
                hanzi: input.hanzi,
                pinyin: input.pinyin,
                english: input.english
            )
            card.exampleChinese = sentence.chinese
            card.exampleEnglish = sentence.english
            card.detailsGeneratedAt = .now
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingSentence = false
    }

    @MainActor
    private func refreshMemoryHint() async {
        guard !isGeneratingMemoryHint else { return }
        errorMessage = nil
        isGeneratingMemoryHint = true

        do {
            let input = generationInput
            let hint = try await service.generateMemoryHint(
                hanzi: input.hanzi,
                pinyin: input.pinyin,
                english: input.english
            )
            card.memoryHintChinese = hint.chinese
            card.memoryHintEnglish = hint.english
            card.memoryHint = nil
            card.detailsGeneratedAt = .now
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingMemoryHint = false
    }

    private var generationInput: GenerationInput {
        GenerationInput(
            hanzi: card.hanzi,
            pinyin: card.pinyin,
            english: card.english
        )
    }

    private var legacyMemoryHintEnglish: String {
        card.memoryHintChinese == nil ? "" : card.memoryHint ?? ""
    }
}

private struct GenerationInput {
    let hanzi: String
    let pinyin: String
    let english: String
}
