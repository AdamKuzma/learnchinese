//
//  ManageCardsView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData
import UIKit

struct ManageCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var allCards: [Flashcard]

    let kind: FlashcardKind

    @State private var showAdd = false
    @State private var selectedCard: Flashcard?
    @State private var searchText = ""
    @State private var searchReveal = PullToRevealSearchState()
    @State private var scrollPhase: SearchRevealScrollPhase = .idle
    @FocusState private var isSearchFocused: Bool
    @AppStorage("vocabularySortMode") private var sortModeRaw = VocabularySortMode.recent.rawValue
    @AppStorage("vocabularySortAscending") private var sortAscending = false

    private var sortMode: VocabularySortMode {
        get { VocabularySortMode(rawValue: sortModeRaw) ?? .recent }
        nonmutating set { sortModeRaw = newValue.rawValue }
    }

    private var cards: [Flashcard] {
        allCards.filter { $0.cardKind == kind }
    }

    private var filteredCards: [Flashcard] {
        FlashcardSearch.filter(cards, query: searchText)
    }

    private var listSections: [VocabularyListSection] {
        guard kind == .vocabulary else {
            return [VocabularyListSection(id: "all", title: nil, cards: filteredCards)]
        }
        return VocabularyListSorter.sections(
            cards: filteredCards,
            mode: sortMode,
            ascending: sortAscending
        )
    }

    var body: some View {
        List {
            if cards.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "rectangle.on.rectangle",
                    description: Text(emptyDescription)
                )
                .appListRowBackground()
            } else if filteredCards.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .appListRowBackground()
            } else {
                ForEach(Array(listSections.enumerated()), id: \.element.id) { index, section in
                    Section {
                        if let title = section.title {
                            AppSectionHeader(title: title)
                                .padding(.top, index == 0 ? 0 : 16)
                                .appListSectionTitle()
                        }

                        ForEach(section.cards) { card in
                            vocabularyRow(card)
                        }
                        .onDelete { offsets in
                            delete(from: section.cards, offsets: offsets)
                        }
                    }
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offsetFromTop in
            var transaction = Transaction()
            if scrollPhase == .userDragging {
                transaction.disablesAnimations = true
            }
            withTransaction(transaction) {
                searchReveal.handleScroll(
                    offsetFromTop: offsetFromTop,
                    phase: scrollPhase,
                    isLockedOpen: isSearchLockedOpen
                )
            }
        }
        .onScrollPhaseChange { oldPhase, newPhase, context in
            let oldMapped = SearchRevealScrollPhase(oldPhase)
            let newMapped = SearchRevealScrollPhase(newPhase)
            scrollPhase = newMapped
            if oldMapped == .userDragging, newMapped != .userDragging {
                let offsetFromTop = context.geometry.contentOffset.y + context.geometry.contentInsets.top
                searchReveal.handleScroll(
                    offsetFromTop: offsetFromTop,
                    phase: .userDragging,
                    isLockedOpen: isSearchLockedOpen
                )
                withAnimation(.easeOut(duration: 0.22)) {
                    searchReveal.handleDragEnded(isLockedOpen: isSearchLockedOpen)
                }
                if !searchReveal.isExpanded {
                    isSearchFocused = false
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .top, spacing: 0) {
            if searchReveal.isExpanded {
                searchField(interactive: true)
            }
        }
        .overlay(alignment: .top) {
            if !searchReveal.isExpanded, searchReveal.revealedHeight > 0 {
                searchField(interactive: false)
                    .frame(height: searchReveal.revealedHeight, alignment: .top)
                    .clipped()
                    .allowsHitTesting(false)
            }
        }
        .appListChrome()
        .navigationTitle(kind == .grammar ? "Grammar" : "Vocabulary")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if kind == .vocabulary {
                    sortMenu
                }
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .accessibilityAction(named: "Search") {
            withAnimation(.easeOut(duration: 0.22)) {
                searchReveal.expand()
            }
            isSearchFocused = true
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AddCardView(kind: kind)
            }
            .appScreenBackground()
        }
        .sheet(item: $selectedCard) { card in
            FlashcardDetailsSheet(card: card)
        }
    }

    private var emptyTitle: String {
        kind == .grammar ? "No grammar yet" : "No vocabulary yet"
    }

    private var emptyDescription: String {
        kind == .grammar
            ? "Add grammar points you want to remember."
            : "Add Chinese words you want to practice."
    }

    private var sortMenu: some View {
        Menu {
            Section("Sort") {
                Picker("Sort", selection: sortModeBinding) {
                    ForEach(VocabularySortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
            }
            Section("Order") {
                Picker("Order", selection: $sortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                .pickerStyle(.inline)
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .accessibilityLabel("Sort vocabulary")
    }

    private var isSearchLockedOpen: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func searchField(interactive: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            if interactive {
                TextField("Search", text: $searchText)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            } else {
                Text("Search")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if interactive, !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(
            Color(uiColor: .tertiarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var sortModeBinding: Binding<VocabularySortMode> {
        Binding(
            get: { sortMode },
            set: { sortMode = $0 }
        )
    }

    private func vocabularyRow(_ card: Flashcard) -> some View {
        Button {
            selectedCard = card
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.hanzi)
                    .font(.title3)
                Text(card.pinyin)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(card.displayEnglish)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .appListRowBackground()
    }

    private func delete(from sectionCards: [Flashcard], offsets: IndexSet) {
        for index in offsets {
            context.delete(sectionCards[index])
        }
    }
}

private extension SearchRevealScrollPhase {
    init(_ phase: ScrollPhase) {
        switch phase {
        case .interacting, .tracking:
            self = .userDragging
        case .decelerating, .animating:
            self = .coasting
        case .idle:
            self = .idle
        @unknown default:
            self = .idle
        }
    }
}

private struct AddCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let kind: FlashcardKind
    var card: Flashcard?

    @State private var hanzi: String
    @State private var pinyin: String
    @State private var english: String
    @State private var isSaving = false

    init(kind: FlashcardKind, card: Flashcard? = nil) {
        self.kind = kind
        self.card = card
        _hanzi = State(initialValue: card?.hanzi ?? "")
        _pinyin = State(initialValue: card?.pinyin ?? "")
        _english = State(initialValue: card?.displayEnglish ?? "")
    }

    private var isEditing: Bool { card != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppLabeledBlock(title: "Chinese") {
                    VStack(alignment: .leading, spacing: 12) {
                        ChinesePreferredTextField(
                            placeholder: kind == .grammar
                                ? "Pattern (e.g. 来不及)"
                                : "Characters (e.g. 你好)",
                            text: $hanzi
                        )
                        .frame(height: 24)

                        EnglishLowercaseTextField(
                            placeholder: "Pinyin (e.g. nǐ hǎo)",
                            text: $pinyin
                        )
                        .frame(height: 24)
                    }
                }

                AppLabeledBlock(title: "Meaning") {
                    EnglishTextField(
                        placeholder: kind == .grammar
                            ? "English (e.g. there's not enough time)"
                            : "English (e.g. hello)",
                        text: $english
                    )
                    .frame(height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .appScreenBackground()
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private var navigationTitle: String {
        if isEditing {
            return kind == .grammar ? "Edit grammar" : "Edit word"
        }
        return kind == .grammar ? "New grammar" : "New word"
    }

    private var isValid: Bool {
        !hanzi.trimmingCharacters(in: .whitespaces).isEmpty &&
        !english.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true

        let trimmedHanzi = hanzi.trimmingCharacters(in: .whitespaces)
        let trimmedPinyin = pinyin.trimmingCharacters(in: .whitespaces)
        var trimmedEnglish = english.trimmingCharacters(in: .whitespaces)
        if kind == .vocabulary {
            trimmedEnglish = trimmedEnglish.capitalizingFirstLetter()
        }

        if let card {
            let coreChanged = card.hanzi != trimmedHanzi
                || card.pinyin != trimmedPinyin
                || card.english != trimmedEnglish
            card.hanzi = trimmedHanzi
            card.pinyin = trimmedPinyin
            card.english = trimmedEnglish
            if coreChanged {
                await generateDetails(for: card)
            }
            try? context.save()
            dismiss()
            return
        }

        let card = Flashcard(
            hanzi: trimmedHanzi,
            pinyin: trimmedPinyin,
            english: trimmedEnglish,
            kind: kind
        )
        context.insert(card)
        AppHaptics.addedItem()
        await generateDetails(for: card)
        try? context.save()
        dismiss()
    }

    @MainActor
    private func generateDetails(for card: Flashcard) async {
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
            // The sheet can retry later once the API key/network is available.
        }
    }
}

private struct ChinesePreferredTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> PreferredLanguageTextField {
        let textField = PreferredLanguageTextField()
        textField.preferredLanguagePrefixes = ["zh-Hans", "zh-Hant", "zh"]
        textField.placeholder = placeholder
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.borderStyle = .none
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.didChangeText(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: PreferredLanguageTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func didChangeText(_ sender: UITextField) {
            text = sender.text ?? ""
        }
    }
}

private struct EnglishLowercaseTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> PreferredLanguageTextField {
        let textField = PreferredLanguageTextField()
        textField.preferredLanguagePrefixes = ["en"]
        textField.placeholder = placeholder
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.borderStyle = .none
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.didChangeText(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: PreferredLanguageTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func didChangeText(_ sender: UITextField) {
            text = sender.text ?? ""
        }
    }
}

private struct EnglishTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeUIView(context: Context) -> PreferredLanguageTextField {
        let textField = PreferredLanguageTextField()
        textField.preferredLanguagePrefixes = ["en"]
        textField.placeholder = placeholder
        textField.autocapitalizationType = .sentences
        textField.autocorrectionType = .default
        textField.borderStyle = .none
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.didChangeText(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: PreferredLanguageTextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func didChangeText(_ sender: UITextField) {
            text = sender.text ?? ""
        }
    }
}

private final class PreferredLanguageTextField: UITextField {
    var preferredLanguagePrefixes: [String] = []

    override var textInputMode: UITextInputMode? {
        guard !preferredLanguagePrefixes.isEmpty else {
            return super.textInputMode
        }

        for inputMode in UITextInputMode.activeInputModes {
            guard let language = inputMode.primaryLanguage else { continue }
            if preferredLanguagePrefixes.contains(where: { language.hasPrefix($0) || language == $0 }) {
                return inputMode
            }
        }
        return super.textInputMode
    }
}
