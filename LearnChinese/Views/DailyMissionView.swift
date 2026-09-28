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
    @State private var savedVocabularyHanzi: Set<String> = []
    @State private var savedGrammarHanzi: Set<String> = []
    @State private var lastTargetKeys: Set<String> = []
    @State private var loaderPattern = AgentPixelLoader.Pattern.allCases.randomElement()!
    @State private var loaderMessage = DailyMissionView.loadingMessages[0]

    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [Flashcard]
    @Query private var progressRecords: [ItemProgress]
    @EnvironmentObject private var blocker: AppBlocker
    private let service = OpenAIFlashcardDetailsService.shared

    var body: some View {
        Group {
            if phase == .generating {
                VStack(spacing: 20) {
                    AgentPixelLoader(pattern: loaderPattern, accessibilityLabel: loaderMessage)
                    ZStack {
                        Text(loaderMessage)
                            .id(loaderMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .transition(Self.loadingMessageTransition)
                    }
                    .frame(maxWidth: 260)
                    .frame(height: 40)
                    .clipped()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground.ignoresSafeArea())
            } else {
                missionForm
            }
        }
        .navigationTitle("Daily Mission")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if phase != .generating {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await startMission() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("New mission")
                }
            }
        }
        .task {
            await startMission()
        }
    }

    @ViewBuilder
    private var missionForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                switch phase {
                case .generating:
                    EmptyView()
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text(errorMessage ?? "Couldn't create a mission.")
                            .foregroundStyle(.red)
                        Button("Try again") {
                            Task { await startMission() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appRaisedCard()
                }

                if let errorMessage, phase == .playing || phase == .evaluating || phase == .result {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appRaisedCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .appScreenBackground()
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func missionSections(_ mission: DailyMission) -> some View {
        if mission.hasGrammarTarget {
            targetSection(
                title: MissionFocus.vocabulary.sectionTitle,
                hanzi: mission.hanzi,
                pinyin: mission.pinyin,
                meaning: mission.meaning,
                kind: .vocabulary
            )
            targetSection(
                title: MissionFocus.grammar.sectionTitle,
                hanzi: mission.grammarHanzi,
                pinyin: mission.grammarPinyin,
                meaning: mission.grammarMeaning,
                kind: .grammar
            )
        } else {
            targetSection(
                title: mission.focus.sectionTitle,
                hanzi: mission.hanzi,
                pinyin: mission.pinyin,
                meaning: mission.meaning,
                kind: targetKind
            )
        }

        AppLabeledBlock(title: "Situation") {
            if showEnglish {
                copyableText(
                    display: mission.situationEnglish,
                    copyText: mission.situationEnglish,
                    pinyin: "",
                    showPinyin: $showSituationPinyin,
                    font: .body
                )
            } else {
                tappableSentence(
                    text: mission.situationChinese,
                    words: mission.situationTokens,
                    pinyin: mission.situationPinyin,
                    showPinyin: $showSituationPinyin,
                    font: .headline
                )
            }
        }

        AppLabeledBlock(title: "Mission") {
            if showEnglish {
                copyableText(
                    display: mission.taskEnglish,
                    copyText: mission.taskEnglish,
                    pinyin: "",
                    showPinyin: $showTaskPinyin,
                    font: .body
                )
            } else {
                tappableSentence(
                    text: mission.taskChinese,
                    words: mission.taskTokens,
                    pinyin: mission.taskPinyin,
                    showPinyin: $showTaskPinyin,
                    font: .headline
                )
            }
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
            Button(showEnglish ? "Show Chinese" : "Show English") {
                showEnglish.toggle()
            }
            if !pinyin.isEmpty {
                Button(showPinyin.wrappedValue ? "Hide Pinyin" : "Show Pinyin") {
                    showPinyin.wrappedValue.toggle()
                }
            }
        } preview: {
            sectionTextPreview(display: display, pinyin: pinyin, showPinyin: showPinyin.wrappedValue, font: font)
        }
    }

    private func tappableSentence(
        text: String,
        words: [MissionWord],
        pinyin: String,
        showPinyin: Binding<Bool>,
        font: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TappableChineseSentence(
                words: words,
                font: font,
                savedHanzi: savedHanzi(for: .vocabulary).union(savedHanzi(for: .grammar)),
                onToggle: toggleWordInFlashcards
            )
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
                UIPasteboard.general.string = text
            }
            Button(showEnglish ? "Show Chinese" : "Show English") {
                showEnglish.toggle()
            }
            if !pinyin.isEmpty {
                Button(showPinyin.wrappedValue ? "Hide Pinyin" : "Show Pinyin") {
                    showPinyin.wrappedValue.toggle()
                }
            }
        } preview: {
            sectionTextPreview(display: text, pinyin: pinyin, showPinyin: showPinyin.wrappedValue, font: font)
        }
    }

    private func targetSection(
        title: String,
        hanzi: String,
        pinyin: String,
        meaning: String,
        kind: FlashcardKind
    ) -> some View {
        AppLabeledBlock(title: title) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(hanzi)
                        .font(.largeTitle.weight(.semibold))
                        .minimumScaleFactor(0.55)
                        .lineLimit(2)
                    if !pinyin.isEmpty {
                        Text(pinyin)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(meaning.capitalizingFirstLetter())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Copy") {
                        UIPasteboard.general.string = hanzi
                    }
                } preview: {
                    targetWordPreview(hanzi: hanzi, pinyin: pinyin, meaning: meaning)
                }

                Button {
                    toggleWordInFlashcards(
                        MissionWord(hanzi: hanzi, pinyin: pinyin, english: meaning),
                        kind: kind
                    )
                } label: {
                    Image(systemName: isSaved(hanzi, kind: kind) ? "checkmark.circle.fill" : "plus.circle")
                }
                .font(.title2)
                .accessibilityLabel(
                    isSaved(hanzi, kind: kind)
                        ? (kind == .grammar ? "Remove from Grammar" : "Remove from Vocabulary")
                        : (kind == .grammar ? "Add to Grammar" : "Add to Vocabulary")
                )
            }
        }
    }

    private func targetWordPreview(hanzi: String, pinyin: String, meaning: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hanzi)
                .font(.largeTitle.weight(.semibold))
            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(meaning.capitalizingFirstLetter())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppSecondaryContainerBackground())
    }

    private func sectionTextPreview(display: String, pinyin: String, showPinyin: Bool, font: Font) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(display)
                .font(font)
            if showPinyin, !pinyin.isEmpty {
                Text(pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppSecondaryContainerBackground())
    }

    private var replySection: some View {
        AppLabeledBlock(title: "Your reply") {
            VStack(alignment: .leading, spacing: 12) {
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
    }

    @ViewBuilder
    private func resultSections(_ evaluation: DailyMissionEvaluation) -> some View {
        AppLabeledBlock(title: "Result") {
            VStack(alignment: .leading, spacing: 12) {
                resultRow("Mission success", evaluation.success ? "Yes" : "No")
                resultSeparator
                resultRow("Meaning", "\(evaluation.meaning)/5")
                resultSeparator
                resultRow("Grammar", "\(evaluation.grammar)/5")
                resultSeparator
                resultRow("Naturalness", "\(evaluation.naturalness)/5")
                resultSeparator
                resultRow(
                    mission?.focus.usedCorrectlyLabel ?? "Target word used correctly",
                    evaluation.targetWordUsedCorrectly ? "Yes" : "No"
                )
                if mission?.hasGrammarTarget == true {
                    resultSeparator
                    resultRow(
                        MissionFocus.grammar.usedCorrectlyLabel,
                        evaluation.targetGrammarUsedCorrectly ? "Yes" : "No"
                    )
                }
            }
        }

        AppLabeledBlock(title: "Feedback") {
            Text(evaluation.feedback)
        }

        if !userResponse.isEmpty {
            AppLabeledBlock(title: "Your reply") {
                Text(userResponse)
                    .font(.headline)
                    .textSelection(.enabled)
            }
        }

        AppLabeledBlock(title: "A more natural version") {
            Text(evaluation.naturalChinese)
                .font(.headline)
                .textSelection(.enabled)
        }

        Button("New mission") {
            Task { await startMission() }
        }
        .frame(maxWidth: .infinity)
        .appRaisedCard()
    }

    private func resultRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private var resultSeparator: some View {
        Color.appSecondaryBorder
            .frame(height: 0.5)
    }

    private static let loadingMessages = [
        "Creating daily mission",
        "Writing today's mission",
        "Crafting a new mission",
        "Setting up today's task",
        "Finding a target word",
        "Building the situation",
        "Preparing today's challenge",
        "Sketching the scene",
        "Picking today's word",
        "Putting a mission together",
        "Making today's mission",
        "Getting the mission ready"
    ]

    private struct LoadingMessageAppearance: ViewModifier {
        var blur: CGFloat
        var opacity: Double

        func body(content: Content) -> some View {
            content
                .blur(radius: blur)
                .opacity(opacity)
        }
    }

    private static let loadingMessageTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .top).combined(with: .modifier(
            active: LoadingMessageAppearance(blur: 10, opacity: 0),
            identity: LoadingMessageAppearance(blur: 0, opacity: 1)
        )),
        removal: .move(edge: .bottom).combined(with: .modifier(
            active: LoadingMessageAppearance(blur: 10, opacity: 0),
            identity: LoadingMessageAppearance(blur: 0, opacity: 1)
        ))
    )

    private static func nextLoadingMessage(after current: String) -> String {
        let messages = loadingMessages
        guard let index = messages.firstIndex(of: current) else {
            return messages.randomElement() ?? "Creating daily mission"
        }
        return messages[(index + 1) % messages.count]
    }

    @MainActor
    private func startMission() async {
        errorMessage = nil
        evaluation = nil
        energyGranted = 0
        savedVocabularyHanzi = []
        savedGrammarHanzi = []
        userResponse = ""
        mission = nil
        showEnglish = false
        showSituationPinyin = false
        showTaskPinyin = false
        loaderPattern = AgentPixelLoader.Pattern.allCases.randomElement()!
        loaderMessage = Self.loadingMessages.randomElement() ?? "Creating daily mission"
        phase = .generating

        let rotateMessages = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, phase == .generating else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    loaderMessage = Self.nextLoadingMessage(after: loaderMessage)
                }
            }
        }
        defer { rotateMessages.cancel() }

        do {
            let difficulty = SharedStore.missionDifficulty
            let vocabSource = SharedStore.missionVocabSource
            let dualTargets = difficulty.usesDualTargets
                ? CardPicker.pickDualMissionTargets(
                    level: SharedStore.hskLevel,
                    cards: cards,
                    progress: progressRecords,
                    source: vocabSource,
                    lastKeys: lastTargetKeys
                )
                : nil
            let targetWord: DailyMissionTargetWord?
            let grammarTarget: DailyMissionTargetWord?
            if let dualTargets {
                targetWord = dualTargets.vocabulary
                grammarTarget = dualTargets.grammar
            } else {
                targetWord = CardPicker.pickMissionTarget(
                    level: SharedStore.hskLevel,
                    cards: cards,
                    progress: progressRecords,
                    source: vocabSource,
                    lastKeys: lastTargetKeys
                )
                grammarTarget = nil
            }
            let generated = try await service.generateMission(
                level: SharedStore.hskLevel,
                difficulty: difficulty,
                themes: SharedStore.missionThemes,
                targetWord: targetWord,
                grammarTarget: grammarTarget
            )
            var shown = Set<String>()
            if let targetWord {
                shown.insert(HanziNormalizer.normalize(targetWord.hanzi))
                ProgressService.markShown(hanzi: targetWord.hanzi, in: modelContext)
            }
            if let grammarTarget {
                shown.insert(HanziNormalizer.normalize(grammarTarget.hanzi))
                ProgressService.markShown(hanzi: grammarTarget.hanzi, in: modelContext)
            }
            lastTargetKeys = shown
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
                SharedStore.recordActivity(.dailyMission)
                energyGranted = blocker.addEnergy(minutes: Energy.dailyMissionReward)
                ProgressService.recordMissionCompletion(hanzi: mission.hanzi, in: modelContext)
                if mission.hasGrammarTarget {
                    ProgressService.recordMissionCompletion(hanzi: mission.grammarHanzi, in: modelContext)
                }
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

    private var targetKind: FlashcardKind {
        mission?.focus == .grammar ? .grammar : .vocabulary
    }

    private func savedHanzi(for kind: FlashcardKind) -> Set<String> {
        let fromStore = Set(
            cards
                .filter { $0.cardKind == kind }
                .map { normalizedHanzi($0.hanzi) }
        )
        let fromSession = kind == .grammar ? savedGrammarHanzi : savedVocabularyHanzi
        return fromStore.union(fromSession)
    }

    private func isSaved(_ hanzi: String, kind: FlashcardKind) -> Bool {
        savedHanzi(for: kind).contains(normalizedHanzi(hanzi))
    }

    private func existingFlashcard(for hanzi: String, kind: FlashcardKind) -> Flashcard? {
        let target = normalizedHanzi(hanzi)
        return cards.first { normalizedHanzi($0.hanzi) == target && $0.cardKind == kind }
    }

    private func toggleWordInFlashcards(_ word: MissionWord) {
        let hanzi = normalizedHanzi(word.hanzi)
        if let existing = cards.first(where: { normalizedHanzi($0.hanzi) == hanzi }) {
            removeFlashcard(hanzi: hanzi, kind: existing.cardKind)
            return
        }
        toggleWordInFlashcards(word, kind: HSKCatalog.bundled.preferredSavedKind(for: hanzi))
    }

    private func toggleWordInFlashcards(_ word: MissionWord, kind: FlashcardKind) {
        let pending = PendingFlashcard(
            hanzi: normalizedHanzi(word.hanzi),
            pinyin: word.pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            english: word.english.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind
        )
        if isSaved(pending.hanzi, kind: kind) {
            removeFlashcard(hanzi: pending.hanzi, kind: kind)
        } else {
            AppHaptics.addedItem()
            Task { await saveFlashcard(pending) }
        }
    }

    private func removeFlashcard(hanzi: String, kind: FlashcardKind) {
        let target = normalizedHanzi(hanzi)
        if let existing = existingFlashcard(for: target, kind: kind) {
            modelContext.delete(existing)
            try? modelContext.save()
        }
        if kind == .grammar {
            savedGrammarHanzi.remove(target)
        } else {
            savedVocabularyHanzi.remove(target)
        }
    }

    private func markSaved(_ hanzi: String, kind: FlashcardKind) {
        if kind == .grammar {
            savedGrammarHanzi.insert(hanzi)
        } else {
            savedVocabularyHanzi.insert(hanzi)
        }
    }

    @MainActor
    private func saveFlashcard(_ pending: PendingFlashcard) async {
        let hanzi = pending.hanzi
        guard existingFlashcard(for: hanzi, kind: pending.kind) == nil else {
            markSaved(hanzi, kind: pending.kind)
            return
        }

        let card = Flashcard(
            hanzi: hanzi,
            pinyin: pending.pinyin,
            english: pending.english,
            kind: pending.kind
        )
        modelContext.insert(card)
        try? modelContext.save()
        markSaved(hanzi, kind: pending.kind)

        do {
            let details = try await OpenAIFlashcardDetailsService.shared.generateAll(
                hanzi: card.hanzi,
                pinyin: card.pinyin,
                english: card.english
            )
            guard let live = existingFlashcard(for: hanzi, kind: pending.kind) else { return }
            live.exampleChinese = details.sentence.chinese
            live.exampleEnglish = details.sentence.english
            live.memoryHintChinese = details.memoryHint.chinese
            live.memoryHintEnglish = details.memoryHint.english
            live.memoryHint = nil
            live.detailsGeneratedAt = .now
            try? modelContext.save()
        } catch {
            // Card still saves; details can be generated later from the quiz sheet.
        }
    }
}

private struct PendingFlashcard {
    let hanzi: String
    let pinyin: String
    let english: String
    let kind: FlashcardKind
}
