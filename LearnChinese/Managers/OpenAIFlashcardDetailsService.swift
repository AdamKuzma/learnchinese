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

    func generateMission(range: HSKRange) async throws -> DailyMission {
        let domain = Self.missionDomains.randomElement() ?? "everyday life"
        let prompt = """
        Create one short Daily Mission for a Mandarin learner.
        Vocabulary range: HSK \(range.min)–\(range.max)
        Situation domain: \(domain)

        Pick one everyday simplified-Chinese word from that HSK range. Do not always pick the most common word in the range.
        Then write a short, realistic situation where the learner would naturally use that word, and a one-line writing task.
        Provide the situation and task in both simplified Chinese and English.

        Return JSON with exactly these string keys:
        hanzi: the target word in simplified Chinese
        pinyin: pinyin with tone marks
        meaning: short English meaning
        situationChinese: 1–2 sentences in simplified Chinese describing the scene
        situationPinyin: pinyin with tone marks for situationChinese
        situationEnglish: the English translation of situationChinese
        taskChinese: one sentence in simplified Chinese telling the learner what to write, using the target word
        taskPinyin: pinyin with tone marks for taskChinese
        taskEnglish: the English translation of taskChinese
        """

        return try await completeJSON(
            prompt: prompt,
            systemPrompt: "You are a concise Mandarin tutor. Return only valid JSON. Create short, realistic daily speaking missions for learners.",
            temperature: 0.9
        )
    }

    func evaluate(mission: DailyMission, userChinese: String) async throws -> DailyMissionEvaluation {
        let prompt = """
        Score this Mandarin learner's reply to a Daily Mission.

        Target word: \(mission.hanzi)
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
        - targetWordUsedCorrectly is true if the target word appears and is used with the right meaning, even if the rest of the sentence is imperfect.

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

    private static let missionDomains = [
        "restaurant",
        "commute",
        "shopping",
        "work",
        "home",
        "school",
        "weather",
        "friends",
        "travel",
        "health"
    ]

    private func completeJSON<Response: Decodable>(
        prompt: String,
        systemPrompt: String = "You are a concise Mandarin tutor. Return only valid JSON. Keep examples learner-friendly. Provide Chinese and English for memory hints when requested.",
        temperature: Double = 0.9
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
                model: model,
                messages: [
                    ChatMessage(
                        role: "system",
                        content: systemPrompt
                    ),
                    ChatMessage(role: "user", content: prompt)
                ],
                temperature: temperature,
                responseFormat: ResponseFormat(type: "json_object")
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
        guard let content = completion.choices.first?.message.content else {
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

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
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
