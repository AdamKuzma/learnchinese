import SwiftUI
import UIKit

struct TappableChineseSentence: View {
    let words: [MissionWord]
    let font: Font
    let savedHanzi: Set<String>
    let onToggle: (MissionWord) -> Void
    var lineSpacing: CGFloat = 6
    var wordVerticalPadding: CGFloat = 2

    @State private var presentedIndex: Int?
    @State private var highlightedIndex: Int?

    private var layoutItems: [ChineseSentenceLayoutItem] {
        ChineseSentenceLayout.items(from: words)
    }

    var body: some View {
        FlowLayout(spacing: 0, lineSpacing: lineSpacing) {
            ForEach(Array(layoutItems.enumerated()), id: \.offset) { index, item in
                wordView(item, index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func wordView(_ item: ChineseSentenceLayoutItem, index: Int) -> some View {
        let isSelected = highlightedIndex == index

        if item.word.isTappable {
            Button {
                highlightedIndex = index
                presentedIndex = index
            } label: {
                Text(item.displayHanzi)
                    .font(font)
                    .padding(.horizontal, 1)
                    .padding(.vertical, wordVerticalPadding)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isSelected ? Color.appForeground.opacity(0.18) : .clear)
                    }
                    .animation(.easeOut(duration: 0.2), value: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows pinyin and translation")
            .popover(isPresented: isPresented(index), arrowEdge: .bottom) {
                WordLookupPopover(
                    word: item.word,
                    savedHanzi: savedHanzi,
                    onToggle: onToggle
                )
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.appSecondaryBackground)
                .background {
                    PopoverWillDismissObserver {
                        highlightedIndex = nil
                    }
                }
            }
        } else {
            Text(item.displayHanzi)
                .font(font)
        }
    }

    private func isPresented(_ index: Int) -> Binding<Bool> {
        Binding(
            get: { presentedIndex == index },
            set: { isPresented in
                if !isPresented {
                    presentedIndex = nil
                    highlightedIndex = nil
                }
            }
        )
    }
}

struct WordLookupPopover: View {
    let word: MissionWord
    let savedHanzi: Set<String>
    let onToggle: (MissionWord) -> Void

    @State private var details: MissionWord
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isSaved: Bool {
        savedHanzi.contains(details.hanzi.trimmingCharacters(in: .whitespacesAndNewlines))
            || savedHanzi.contains(word.hanzi.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    init(word: MissionWord, savedHanzi: Set<String>, onToggle: @escaping (MissionWord) -> Void) {
        self.word = word
        self.savedHanzi = savedHanzi
        self.onToggle = onToggle
        _details = State(initialValue: word)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(details.hanzi)
                        .font(.title2.weight(.semibold))

                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 4)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            Task { await loadDetails() }
                        }
                        .font(.footnote)
                    } else {
                        if !details.pinyin.isEmpty {
                            Text(details.pinyin)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if !details.english.isEmpty {
                            Text(details.english.capitalizingFirstLetter())
                                .font(.subheadline)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button {
                    onToggle(details)
                } label: {
                    Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle")
                }
                .font(.title2)
                .disabled(isLoading || !details.hasDetails)
                .accessibilityLabel(isSaved ? "Remove from Vocabulary" : "Add to Vocabulary")
            }
        }
        .padding(14)
        .frame(minWidth: 220)
        .background(Color.appSecondaryBackground)
        .task {
            await loadDetails()
        }
    }

    @MainActor
    private func loadDetails() async {
        if details.hasDetails { return }
        isLoading = true
        errorMessage = nil
        do {
            details = try await OpenAIFlashcardDetailsService.shared.lookupWord(hanzi: word.hanzi)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct PopoverWillDismissObserver: UIViewControllerRepresentable {
    var onWillDismiss: () -> Void

    func makeUIViewController(context: Context) -> ObserverController {
        ObserverController(onWillDismiss: onWillDismiss)
    }

    func updateUIViewController(_ uiViewController: ObserverController, context: Context) {
        uiViewController.onWillDismiss = onWillDismiss
    }

    final class ObserverController: UIViewController {
        var onWillDismiss: () -> Void

        init(onWillDismiss: @escaping () -> Void) {
            self.onWillDismiss = onWillDismiss
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard isInDismissingPresentation else { return }
            onWillDismiss()
        }

        private var isInDismissingPresentation: Bool {
            var current: UIViewController? = self
            while let viewController = current {
                if viewController.isBeingDismissed { return true }
                current = viewController.parent
            }
            return false
        }
    }
}

struct ChineseSentenceLayoutItem: Equatable {
    var word: MissionWord
    var displayHanzi: String
}

enum ChineseSentenceLayout {
    static func items(from words: [MissionWord]) -> [ChineseSentenceLayoutItem] {
        var items: [ChineseSentenceLayoutItem] = []
        var pendingOpen = ""

        for word in words {
            switch word.lineBreakRole {
            case .openingPunctuation:
                pendingOpen += word.hanzi
            case .closingPunctuation:
                if var last = items.last {
                    last.displayHanzi += word.hanzi
                    items[items.count - 1] = last
                } else {
                    items.append(
                        ChineseSentenceLayoutItem(word: word, displayHanzi: pendingOpen + word.hanzi)
                    )
                    pendingOpen = ""
                }
            case .content:
                items.append(
                    ChineseSentenceLayoutItem(word: word, displayHanzi: pendingOpen + word.hanzi)
                )
                pendingOpen = ""
            }
        }

        if !pendingOpen.isEmpty {
            if var last = items.last {
                last.displayHanzi += pendingOpen
                items[items.count - 1] = last
            } else {
                items.append(
                    ChineseSentenceLayoutItem(
                        word: MissionWord(hanzi: pendingOpen, pinyin: "", english: ""),
                        displayHanzi: pendingOpen
                    )
                )
            }
        }

        return items
    }
}

private extension MissionWord {
    enum LineBreakRole {
        case openingPunctuation
        case closingPunctuation
        case content
    }

    var lineBreakRole: LineBreakRole {
        let scalars = hanzi.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !scalars.isEmpty else { return .closingPunctuation }
        if scalars.allSatisfy({ CJKLineBreaking.cannotEndLine.contains($0) }) {
            return .openingPunctuation
        }
        if scalars.allSatisfy({ CJKLineBreaking.cannotStartLine.contains($0) }) {
            return .closingPunctuation
        }
        let punctuation = CharacterSet.punctuationCharacters.union(.symbols)
        if scalars.allSatisfy({ punctuation.contains($0) }) {
            return .closingPunctuation
        }
        return .content
    }
}

private enum CJKLineBreaking {
    static let cannotStartLine = CharacterSet(charactersIn: "。．.！!？?，,、；;：:）》」』】〉›»’”…—～%、‰")
    static let cannotEndLine = CharacterSet(charactersIn: "（《「『【〈‹«‘“")
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let proposedWidth = proposal.width ?? .infinity
        let result = arrange(in: proposedWidth, subviews: subviews)
        if proposedWidth.isFinite {
            return CGSize(width: proposedWidth, height: result.size.height)
        }
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(in: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private func arrange(in maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        let canWrap = maxWidth.isFinite && maxWidth > 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if canWrap, x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }

        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}
