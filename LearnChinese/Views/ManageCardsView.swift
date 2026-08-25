//
//  ManageCardsView.swift
//  LearnChinese
//

import SwiftUI
import SwiftData
import UIKit

struct ManageCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Flashcard.createdAt, order: .reverse) private var cards: [Flashcard]

    @State private var showAdd = false

    var body: some View {
        List {
            if cards.isEmpty {
                ContentUnavailableView(
                    "No flashcards yet",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Add Chinese words you want to practice.")
                )
            } else {
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.hanzi)
                            .font(.title3)
                        Text(card.pinyin)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(card.english)
                            .font(.subheadline)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Flashcards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            NavigationStack {
                AddCardView()
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            context.delete(cards[index])
        }
    }
}

private struct AddCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var hanzi = ""
    @State private var pinyin = ""
    @State private var english = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            Section("Chinese") {
                ChinesePreferredTextField(
                    placeholder: "Characters (e.g. 你好)",
                    text: $hanzi
                )
                EnglishLowercaseTextField(
                    placeholder: "Pinyin (e.g. nǐ hǎo)",
                    text: $pinyin
                )
            }
            Section("Meaning") {
                EnglishTextField(
                    placeholder: "English (e.g. hello)",
                    text: $english
                )
            }
        }
        .navigationTitle("New flashcard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .disabled(!isValid || isSaving)
            }
        }
    }

    private var isValid: Bool {
        !hanzi.trimmingCharacters(in: .whitespaces).isEmpty &&
        !english.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true

        let card = Flashcard(
            hanzi: hanzi.trimmingCharacters(in: .whitespaces),
            pinyin: pinyin.trimmingCharacters(in: .whitespaces),
            english: english.trimmingCharacters(in: .whitespaces)
        )
        context.insert(card)

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

        try? context.save()
        dismiss()
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
