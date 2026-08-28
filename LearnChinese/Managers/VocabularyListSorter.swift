//
//  VocabularyListSorter.swift
//  LearnChinese
//

import Foundation

enum VocabularySortMode: String, CaseIterable, Identifiable, Codable {
    case recent
    case alphabetical
    case partOfSpeech
    case hskLevel

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .alphabetical: return "Alphabetical"
        case .partOfSpeech: return "Part of speech"
        case .hskLevel: return "Level"
        }
    }
}

struct VocabularyListSection: Identifiable {
    let id: String
    let title: String?
    let cards: [Flashcard]
}

enum VocabularyListSorter {
    private static let unsortedID = "unsorted"
    private static let uncategorizedTitle = "Uncategorized"

    static func sections(
        cards: [Flashcard],
        mode: VocabularySortMode,
        ascending: Bool,
        catalog: HSKCatalog = .bundled
    ) -> [VocabularyListSection] {
        switch mode {
        case .recent:
            let sorted = cards.sorted { lhs, rhs in
                ascending ? lhs.createdAt < rhs.createdAt : lhs.createdAt > rhs.createdAt
            }
            return [VocabularyListSection(id: "all", title: nil, cards: sorted)]

        case .alphabetical:
            let sorted = cards.sorted { lhs, rhs in
                comparePinyin(lhs, rhs, ascending: ascending)
            }
            return [VocabularyListSection(id: "all", title: nil, cards: sorted)]

        case .partOfSpeech:
            return groupedByPartOfSpeech(cards, ascending: ascending)

        case .hskLevel:
            return groupedByHSK(cards, ascending: ascending, catalog: catalog)
        }
    }

    private static func groupedByPartOfSpeech(
        _ cards: [Flashcard],
        ascending: Bool
    ) -> [VocabularyListSection] {
        var grouped: [String: [Flashcard]] = [:]
        var unsorted: [Flashcard] = []

        for card in cards {
            guard let raw = card.partsOfSpeech.first, !raw.isEmpty else {
                unsorted.append(card)
                continue
            }
            let title = PartOfSpeechLabel.displayName(for: raw)
            grouped[title, default: []].append(card)
        }

        let titles = grouped.keys.sorted { lhs, rhs in
            let comparison = lhs.localizedStandardCompare(rhs)
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }

        var sections = titles.map { title in
            VocabularyListSection(
                id: "pos-\(title)",
                title: title,
                cards: grouped[title]!.sorted { comparePinyin($0, $1, ascending: true) }
            )
        }

        if !unsorted.isEmpty {
            sections.append(
                VocabularyListSection(
                    id: unsortedID,
                    title: uncategorizedTitle,
                    cards: unsorted.sorted { $0.createdAt > $1.createdAt }
                )
            )
        }
        return sections
    }

    private static func groupedByHSK(
        _ cards: [Flashcard],
        ascending: Bool,
        catalog: HSKCatalog
    ) -> [VocabularyListSection] {
        var grouped: [Int: [Flashcard]] = [:]
        var unsorted: [Flashcard] = []

        for card in cards {
            guard let level = catalog.vocab(for: card.hanzi)?.level else {
                unsorted.append(card)
                continue
            }
            grouped[level, default: []].append(card)
        }

        let levels = grouped.keys.sorted { lhs, rhs in
            ascending ? lhs < rhs : lhs > rhs
        }

        var sections = levels.map { level in
            VocabularyListSection(
                id: "hsk-\(level)",
                title: "HSK \(level)",
                cards: grouped[level]!.sorted { comparePinyin($0, $1, ascending: true) }
            )
        }

        if !unsorted.isEmpty {
            sections.append(
                VocabularyListSection(
                    id: unsortedID,
                    title: uncategorizedTitle,
                    cards: unsorted.sorted { $0.createdAt > $1.createdAt }
                )
            )
        }
        return sections
    }

    private static func comparePinyin(_ lhs: Flashcard, _ rhs: Flashcard, ascending: Bool) -> Bool {
        let left = pinyinKey(lhs)
        let right = pinyinKey(rhs)
        let comparison = left.localizedStandardCompare(right)
        if comparison == .orderedSame {
            return ascending ? lhs.hanzi < rhs.hanzi : lhs.hanzi > rhs.hanzi
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private static func pinyinKey(_ card: Flashcard) -> String {
        let pinyin = card.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        if pinyin.isEmpty {
            return card.hanzi
        }
        return pinyin.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
