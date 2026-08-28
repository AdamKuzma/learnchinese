//
//  OpenAIFlashcardDetailsService.swift
//  LearnChinese
//

import Foundation

struct FlashcardSentenceDetails: Sendable {
    let chinese: String
    let english: String
}

struct FlashcardGeneratedDetails: Sendable {
    let sentence: FlashcardSentenceDetails
    let memoryHint: FlashcardSentenceDetails
}

actor OpenAIFlashcardDetailsService {
    static let shared = OpenAIFlashcardDetailsService()

    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model = "gpt-4o-mini"
    private let urlSession: URLSession
    private let apiKeyProvider: @Sendable () -> String?

    init(
        urlSession: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () -> String? = OpenAIAPIKey.resolve
    ) {
        self.urlSession = urlSession
        self.apiKeyProvider = apiKeyProvider
    }

    func generateAll(hanzi: String, pinyin: String, english: String) async throws -> FlashcardGeneratedDetails {
        let prompt = """
        Generate study details for this Mandarin flashcard.
        Chinese word: \(hanzi)
        Pinyin: \(pinyin.isEmpty ? "unknown" : pinyin)
        English meaning: \(english)

        Return JSON with exactly these string keys:
        sentenceChinese: one natural, short Chinese example sentence using the word
        sentenceEnglish: the English translation of sentenceChinese
        memoryHintChinese: a concise memory hint written in simplified Chinese, explaining character parts, word logic, sound, or imagery
        memoryHintEnglish: the English translation of memoryHintChinese
        """

        let response: DetailsResponse = try await completeJSON(prompt: prompt)
        return FlashcardGeneratedDetails(
            sentence: FlashcardSentenceDetails(
                chinese: response.sentenceChinese,
                english: response.sentenceEnglish
            ),
            memoryHint: FlashcardSentenceDetails(
                chinese: response.memoryHintChinese,
                english: response.memoryHintEnglish
            )
        )
    }

    func generateSentence(hanzi: String, pinyin: String, english: String) async throws -> FlashcardSentenceDetails {
        let prompt = """
        Generate a different example sentence for this Mandarin flashcard.
        Chinese word: \(hanzi)
        Pinyin: \(pinyin.isEmpty ? "unknown" : pinyin)
        English meaning: \(english)

        Return JSON with exactly these string keys:
        sentenceChinese: one natural, short Chinese example sentence using the word
        sentenceEnglish: the English translation of sentenceChinese
        """

        let response: SentenceResponse = try await completeJSON(prompt: prompt)
        return FlashcardSentenceDetails(
            chinese: response.sentenceChinese,
            english: response.sentenceEnglish
        )
    }

    func generateMemoryHint(hanzi: String, pinyin: String, english: String) async throws -> FlashcardSentenceDetails {
        let prompt = """
        Generate a different memory hint for this Mandarin flashcard.
        Chinese word: \(hanzi)
        Pinyin: \(pinyin.isEmpty ? "unknown" : pinyin)
        English meaning: \(english)

        Return JSON with exactly these string keys:
        memoryHintChinese: a concise memory hint written in simplified Chinese, explaining character parts, word logic, sound, or imagery
        memoryHintEnglish: the English translation of memoryHintChinese
        """

        let response: MemoryHintResponse = try await completeJSON(prompt: prompt)
        return FlashcardSentenceDetails(
            chinese: response.memoryHintChinese,
            english: response.memoryHintEnglish
        )
    }

    func generateWordSyntax(hanzi: String, pinyin: String, english: String) async throws -> FlashcardStudyLexicon {
        let prompt = """
        Generate compact study labels for this Mandarin flashcard.
        Chinese: \(hanzi)
        Pinyin: \(pinyin.isEmpty ? "unknown" : pinyin)
        English meaning: \(english)

        Return JSON with exactly these keys:
        partOfSpeech: array of 1–3 short English labels for how the word is used (noun, verb, adj, adv, particle, measure word, pattern, etc.)
        characters: array with one object per Chinese character in the word, each with:
          hanzi: that one character
          pinyin: pinyin with tone marks for that character
          meaning: short English gloss for that character in this word

        Do not include example sentences.
        Use simplified Chinese.
        """

        return try await completeJSON(
            prompt: prompt,
            systemPrompt: "You are a concise Mandarin tutor. Return only valid JSON. Use simplified Chinese and pinyin with tone marks. Keep character glosses short.",
            temperature: 0.2,
            maxTokens: 800
        )
    }

    func generateExampleSentences(hanzi: String, pinyin: String, english: String) async throws -> [FlashcardExampleSentence] {
        let prompt = """
        Generate different example sentences for this Mandarin flashcard.
        Chinese: \(hanzi)
        Pinyin: \(pinyin.isEmpty ? "unknown" : pinyin)
        English meaning: \(english)

        Return JSON with exactly this key:
        sentences: array of at least 5 example sentences using the word. Each sentence object has:
          tokens: array of every character and punctuation mark in order. Each token has:
            hanzi: exactly one character or punctuation mark
            pinyin: pinyin with tone marks for that character, or "" for punctuation
          english: English translation of the full sentence

        \(Self.exampleSentenceVarietyGuidance(hanzi: hanzi))

        Split every Chinese character into its own token. Use simplified Chinese.
        """

        let response: ExampleSentencesResponse = try await completeJSON(
            prompt: prompt,
            systemPrompt: "You are a concise Mandarin tutor. Return only valid JSON. Use simplified Chinese and pinyin with tone marks. Split Chinese character-by-character. Provide at least 5 varied sentences.",
            temperature: 0.95,
            maxTokens: 4000
        )
        return response.sentences
    }

    private static func exampleSentenceVarietyGuidance(hanzi: String) -> String {
        """
        Variety rules for \(hanzi):
        Do not write five near-paraphrases. Each sentence must feel like a different situation and a different length.

        Include all of these:
        1. One very short everyday sentence (roughly 4–10 characters besides the target).
        2. One medium spoken line from daily life.
        3. One longer sentence with a specific setting: a place, people, and what just happened.
        4. One question or rhetorical question.
        5. One sentence that uses a different sense, collocation, or register (concrete vs emotional, casual vs formal, inner state vs outward action).

        Mix subjects, tenses, and outcomes. Avoid repeating the same sentence frame.
        """
    }

    func generateMission(
        level: Int,
        difficulty: MissionDifficulty,
        themes: Set<MissionTheme>,
        knownVocabulary: [String] = [],
        knownGrammar: [String] = [],
        targetWord: DailyMissionTargetWord? = nil
    ) async throws -> DailyMission {
        let hskLevel = min(max(level, HSKRange.levels.lowerBound), HSKRange.levels.upperBound)
        let selectedThemes = themes.isEmpty ? Set(MissionTheme.allCases) : themes
        let theme = selectedThemes.randomElement() ?? .everydayLife
        let focus = targetWord?.focus ?? MissionFocus.allCases.randomElement() ?? .vocabulary
        let knownTargets = Self.dedupedKnownItems(
            focus == .grammar ? knownGrammar : knownVocabulary
        )
        let targetKind = focus == .grammar ? "grammar phrase or pattern" : "word"
        let prompt = """
        Create one Daily Mission for a Mandarin learner.
        HSK level: \(hskLevel)
        Difficulty: \(difficulty.title)
        Theme: \(theme.title)
        Target type: \(focus == .grammar ? "grammar" : "vocabulary")

        \(Self.targetGuidance(for: hskLevel, focus: focus, targetWord: targetWord, knownTargets: knownTargets))

        Raise or lower complexity only through the situation and the writing task, never by swapping in easier or harder HSK vocabulary.

        Difficulty guidance:
        \(difficulty.promptGuidance)

        Theme guidance:
        \(theme.promptGuidance)

        Make the situation specific and interesting: name a place, people, and what just happened. Avoid generic textbook scenes.

        Return JSON with exactly these string keys:
        focus: "\(focus.rawValue)"
        hanzi: the target \(targetKind) in simplified Chinese
        pinyin: pinyin with tone marks
        meaning: \(focus == .grammar ? "a short English explanation of how the pattern is used" : "short English meaning")
        situationChinese: the situation in simplified Chinese
        situationPinyin: pinyin with tone marks for situationChinese
        situationEnglish: English translation of situationChinese
        taskChinese: the writing task in simplified Chinese using the target
        taskPinyin: pinyin with tone marks for taskChinese
        taskEnglish: English translation of taskChinese
        """

        let systemPrompt = targetWord == nil
            ? "You are a concise Mandarin tutor. Return only valid JSON with all requested string keys present. Obey the HSK vocabulary and target-type rules exactly. Prefer targets the learner has not already saved."
            : "You are a concise Mandarin tutor. Return only valid JSON with all requested string keys present. Use the required target exactly. Do not replace it with a different word or pattern."

        var mission: DailyMission = try await completeJSON(
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: 0.95
        )
        mission.focus = focus

        if targetWord == nil, Self.isKnown(mission.hanzi, in: knownTargets) {
            let retryPrompt = prompt + """


            The previous target "\(mission.hanzi)" is already in the learner's saved list. Pick a different unused HSK \(hskLevel) \(focus == .grammar ? "grammar pattern" : "word").
            """
            mission = try await completeJSON(
                prompt: retryPrompt,
                systemPrompt: "You are a concise Mandarin tutor. Return only valid JSON with all requested string keys present. Obey the HSK vocabulary and target-type rules exactly. Never reuse a saved target.",
                temperature: 1.0
            )
            mission.focus = focus
        }

        if let targetWord {
            mission.hanzi = targetWord.hanzi
            mission.pinyin = targetWord.pinyin
            mission.meaning = targetWord.meaning
            mission.focus = targetWord.focus
        }

        return mission
    }

    private static let knownItemsLimit = 120

    private static func dedupedKnownItems(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for item in items {
            let value = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { continue }
            unique.append(value)
            if unique.count == knownItemsLimit { break }
        }
        return unique
    }

    private static func isKnown(_ hanzi: String, in known: [String]) -> Bool {
        let target = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return false }
        return known.contains(target)
    }

    private static func knownItemsGuidance(focus: MissionFocus, items: [String]) -> String {
        guard !items.isEmpty else { return "" }
        let kind = focus == .grammar ? "grammar patterns" : "words"
        return """
        Already-known \(kind):
        \(items.joined(separator: "、"))
        Do not use any of these as the target. Strongly prefer a brand-new HSK target the learner has not saved yet.
        """
    }

    private static func targetGuidance(
        for level: Int,
        focus: MissionFocus,
        targetWord: DailyMissionTargetWord?,
        knownTargets: [String]
    ) -> String {
        if let targetWord {
            let kind = focus == .grammar ? "grammar phrase or pattern" : "word"
            return """
            Required target \(kind) — use this exact target. Do not pick a different \(kind).
            hanzi: \(targetWord.hanzi)
            pinyin: \(targetWord.pinyin)
            meaning: \(targetWord.meaning)

            Write the situation and task around this target.
            Situation and task Chinese should stay around HSK \(level) complexity. The required target itself must still be used even if it is not from that HSK list.
            """
        }

        return """
        \(hskTargetGuidance(for: level, focus: focus))

        \(knownItemsGuidance(focus: focus, items: knownTargets))
        """
    }

    private static func hskTargetGuidance(for level: Int, focus: MissionFocus) -> String {
        switch focus {
        case .vocabulary:
            return hskVocabularyGuidance(for: level)
        case .grammar:
            return hskGrammarGuidance(for: level)
        }
    }

    private static func hskVocabularyGuidance(for level: Int) -> String {
        if level <= 1 {
            return """
            Vocabulary rules:
            Use only official HSK 1 words. The target word must come from the HSK 1 list.
            Do not use words from HSK 2 or higher.
            """
        }

        let previous = "HSK 1–\(level - 1)"
        return """
        Vocabulary rules:
        HSK \(level) means words newly introduced on the official HSK \(level) list, NOT the cumulative \(previous) plus HSK \(level) vocabulary.

        Target word:
        Pick one content word (noun, verb, adjective, or adverb) that first appears at HSK \(level).
        It must not be on any \(previous) list. Do not pick a basic everyday word from an earlier level.

        Situation and task Chinese:
        Heavily prioritize HSK \(level) new vocabulary for all content words (nouns, verbs, adjectives, adverbs).
        Do not use \(previous) content words. If a needed idea was taught before HSK \(level), rephrase so the sentence uses HSK \(level) words instead.
        You may use only the minimum earlier-level function words required for grammar: particles such as 的 了 吗 呢 吧 着 过, personal pronouns, 是/有/在, numbers, and measure words.
        Do not use any word above HSK \(level).
        """
    }

    private static func hskGrammarGuidance(for level: Int) -> String {
        let previousNote: String
        if level <= 1 {
            previousNote = "Use only HSK 1 grammar. Do not use patterns from HSK 2 or higher."
        } else {
            previousNote = """
            The pattern must be first taught at HSK \(level), not a basic HSK 1–\(level - 1) pattern.
            Surrounding content words should still be newly introduced at HSK \(level).
            You may use only the minimum earlier-level function words required for grammar: particles such as 的 了 吗 呢 吧 着 过, personal pronouns, 是/有/在, numbers, and measure words.
            Do not use any word or pattern above HSK \(level).
            """
        }

        return """
        Target type: grammar phrase
        Pick one short grammar pattern, set phrase, or function expression — not a simple content noun, verb, or adjective.
        Good examples of this kind of target (use only if they match HSK \(level); otherwise pick a different HSK \(level) pattern): 什么的, 千万, 来不及, 要不然, 对了, 再说, 越来越, 不得不, 还是, 把.
        hanzi should be the pattern itself, typically 2–6 characters, not a full sentence.
        meaning should explain how the pattern is used in English, not just a one-word gloss.
        The situation should make this pattern natural to say. The writing task must require using this exact pattern correctly.

        \(previousNote)
        """
    }

    func lookupWord(hanzi: String) async throws -> MissionWord {
        let prompt = """
        Look up this simplified Chinese text as one lexical word or set phrase, not character by character.
        Text: \(hanzi)

        Return JSON with exactly these string keys:
        hanzi: the same word as the input
        pinyin: pinyin with tone marks
        english: a short English meaning
        """

        let response: WordLookupResponse = try await completeJSON(
            prompt: prompt,
            systemPrompt: "You are a concise Mandarin tutor. Return only valid JSON. Treat the input as one word or phrase.",
            temperature: 0.2
        )

        return MissionWord(
            hanzi: hanzi.trimmingCharacters(in: .whitespacesAndNewlines),
            pinyin: response.pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            english: response.english.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func evaluate(mission: DailyMission, userChinese: String) async throws -> DailyMissionEvaluation {
        let prompt = """
        Score this Mandarin learner's reply to a Daily Mission.

        Target type: \(mission.focus == .grammar ? "grammar pattern" : "vocabulary word")
        Target: \(mission.hanzi)
        Pinyin: \(mission.pinyin)
        Meaning: \(mission.meaning)
        Situation (Chinese): \(mission.situationChinese)
        Situation (English): \(mission.situationEnglish)
        Task (Chinese): \(mission.taskChinese)
        Task (English): \(mission.taskEnglish)
        Learner reply (Chinese): \(userChinese)

        You are a generous tutor for HSK learners. Score the communicative task, not native polish.

        Scoring:
        - 4–5: a native would understand it and the task is done. Minor missing particles (吧, 了, 啊, 呢), slightly stiff wording, or a missing period are still 4–5.
        - 3: understandable but has a real grammar or word-choice problem.
        - 1–2: wrong meaning, unintelligible, or the task was not done.
        - Do not drop grammar or naturalness below 4 only because the sentence could be a bit more native.
        - targetWordUsedCorrectly is true if the target \(mission.focus == .grammar ? "grammar pattern" : "word") appears and is used with the right meaning, even if the rest of the sentence is imperfect.

        Feedback: 1–2 short English sentences. Praise what worked. Mention only real issues. Do not treat missing 吧 / 了 / tone-softening as a failure.

        naturalChinese: a slightly more natural rewrite. Small polish is fine; do not imply the original failed.

        Return JSON with exactly these keys:
        meaning: integer 1-5 (did they convey the intended meaning)
        grammar: integer 1-5
        naturalness: integer 1-5
        targetWordUsedCorrectly: boolean
        feedback: short English feedback (2 sentences max)
        naturalChinese: one more-natural Chinese version of their reply
        """

        let response: EvaluationResponse = try await completeJSON(
            prompt: prompt,
            systemPrompt: "You are a generous Mandarin tutor for learners. Return only valid JSON. Reward successful communication. Do not fail replies for missing particles or small naturalness tweaks.",
            temperature: 0.3
        )

        let meaning = response.meaning.clamped(to: 1...5)
        let grammar = response.grammar.clamped(to: 1...5)
        let naturalness = response.naturalness.clamped(to: 1...5)
        let usedWord = response.targetWordUsedCorrectly

        return DailyMissionEvaluation(
            success: usedWord && meaning >= 3,
            meaning: meaning,
            grammar: grammar,
            naturalness: naturalness,
            targetWordUsedCorrectly: usedWord,
            feedback: response.feedback,
            naturalChinese: response.naturalChinese
        )
    }

    private func completeJSON<Response: Decodable>(
        prompt: String,
        systemPrompt: String = "You are a concise Mandarin tutor. Return only valid JSON. Keep examples learner-friendly. Provide Chinese and English for memory hints when requested.",
        temperature: Double = 0.9,
        model: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> Response {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty
        else {
            throw OpenAIFlashcardDetailsError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatCompletionRequest(
                model: model ?? self.model,
                messages: [
                    ChatMessage(
                        role: "system",
                        content: systemPrompt
                    ),
                    ChatMessage(role: "user", content: prompt)
                ],
                temperature: temperature,
                responseFormat: ResponseFormat(type: "json_object"),
                maxTokens: maxTokens
            )
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIFlashcardDetailsError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw OpenAIFlashcardDetailsError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty
        else {
            throw OpenAIFlashcardDetailsError.emptyResponse
        }

        let jsonData = Data(extractJSONObject(from: content).utf8)
        return try JSONDecoder().decode(Response.self, from: jsonData)
    }

    private func extractJSONObject(from content: String) -> String {
        guard let start = content.firstIndex(of: "{"),
              let end = content.lastIndex(of: "}"),
              start <= end
        else {
            return content
        }
        return String(content[start...end])
    }
}

enum OpenAIFlashcardDetailsError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case requestFailed(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your OpenAI API key before generating flashcard details."
        case .invalidResponse:
            return "OpenAI returned an invalid response."
        case .emptyResponse:
            return "OpenAI returned an empty response."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "OpenAI request failed (\(statusCode)): \(message)"
            }
            return "OpenAI request failed with status \(statusCode)."
        }
    }
}

private enum OpenAIAPIKey {
    static func resolve() -> String? {
        if let value = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !value.isEmpty {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !value.isEmpty,
           !value.hasPrefix("$(") {
            return value
        }

        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any],
              let value = plist["OPENAI_API_KEY"] as? String,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(responseFormat, forKey: .responseFormat)
        try container.encodeIfPresent(maxTokens, forKey: .maxTokens)
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String?
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct DetailsResponse: Decodable {
    let sentenceChinese: String
    let sentenceEnglish: String
    let memoryHintChinese: String
    let memoryHintEnglish: String
}

private struct SentenceResponse: Decodable {
    let sentenceChinese: String
    let sentenceEnglish: String
}

private struct MemoryHintResponse: Decodable {
    let memoryHintChinese: String
    let memoryHintEnglish: String
}

private struct ExampleSentencesResponse: Decodable {
    let sentences: [FlashcardExampleSentence]
}

private struct WordLookupResponse: Decodable {
    let pinyin: String
    let english: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinyin = try container.decodeIfPresent(String.self, forKey: .pinyin) ?? ""
        english = try container.decodeIfPresent(String.self, forKey: .english) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case pinyin, english
    }
}

private struct EvaluationResponse: Decodable {
    let meaning: Int
    let grammar: Int
    let naturalness: Int
    let targetWordUsedCorrectly: Bool
    let feedback: String
    let naturalChinese: String
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
