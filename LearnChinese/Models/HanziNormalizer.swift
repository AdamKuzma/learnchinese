//
//  HanziNormalizer.swift
//  LearnChinese
//

import Foundation

enum HanziNormalizer {
    static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
    }

    /// Official HSK rows sometimes use optional parentheses, e.g. 没（有）.
    /// Include compact (没) and expanded (没有) forms so user flashcards still match.
    static func lookupKeys(for value: String) -> [String] {
        let key = normalize(value)
        guard !key.isEmpty else { return [] }

        var omitted = ""
        var expanded = ""
        omitted.reserveCapacity(key.count)
        expanded.reserveCapacity(key.count)

        var index = key.startIndex
        while index < key.endIndex {
            let character = key[index]
            if character == "（" || character == "(" {
                guard let close = key[index...].firstIndex(where: { $0 == "）" || $0 == ")" }) else {
                    omitted.append(character)
                    expanded.append(character)
                    index = key.index(after: index)
                    continue
                }
                let innerStart = key.index(after: index)
                expanded.append(contentsOf: key[innerStart..<close])
                index = key.index(after: close)
                continue
            }
            omitted.append(character)
            expanded.append(character)
            index = key.index(after: index)
        }

        var keys = [key]
        let omittedKey = normalize(omitted)
        let expandedKey = normalize(expanded)
        if omittedKey != key, !omittedKey.isEmpty { keys.append(omittedKey) }
        if expandedKey != key, expandedKey != omittedKey, !expandedKey.isEmpty { keys.append(expandedKey) }
        return keys
    }
}
