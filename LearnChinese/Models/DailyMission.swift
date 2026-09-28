//
//  DailyMission.swift
//  LearnChinese
//

import Foundation

enum MissionDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy
    case medium
    case hard
    case extreme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }

    var promptGuidance: String {
        switch self {
        case .easy:
            return """
            Keep it short and immediately understandable.
            The situation can be a sentence, a two-line exchange, a notice, a message, or someone speaking to the learner — not always a third-person story.
            The task is one brief thing the learner would actually say, ask, or send.
            Do not always use 请你说. No twists or extra constraints.
            """
        case .medium:
            return """
            Keep it realistic, with one specific detail, preference, or small constraint.
            Vary the situation form: a message, a short dialogue already in progress, a sign, a phone call, or a direct scene.
            The task is one complete reply that includes a reason or a little extra information.
            Do not always use 请你告诉. No high-stakes conflict.
            """
        case .hard:
            return """
            Make a layered situation: a goal plus an obstacle, competing needs, or social nuance.
            Use one or two sentences, or a short exchange plus one beat of complication.
            The task is a fuller reply of about two sentences that explains, persuades, compares, or handles the complication.
            The reply must use both the target vocabulary word and the target grammar pattern.
            Vary how the task is asked; do not always say 请你说.
            """
        case .extreme:
            return """
            Make a memorable, high-pressure, or socially complex situation that still feels plausible.
            Include multiple moving parts: new information, a constraint, and a person or system to manage.
            Situation: two sentences, a message thread, or a short dialogue with a twist.
            Task: a complete response of two or three sentences that handles the issue, states a decision, and gives a reason.
            The reply must use both the target vocabulary word and the target grammar pattern.
            """
        }
    }

    var usesDualTargets: Bool {
        self == .hard || self == .extreme
    }
}

enum MissionVocabSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case discoverHSK
    case practiceDeck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .discoverHSK: return "Discover HSK"
        case .practiceDeck: return "My vocabulary"
        }
    }

    var settingsTitle: String {
        switch self {
        case .discoverHSK: return "Discover HSK: full level list"
        case .practiceDeck: return "My vocabulary: saved words"
        }
    }

    var prefersSavedVocabulary: Bool {
        self == .practiceDeck
    }
}

enum MissionTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case everydayLife
    case travel
    case social
    case problemSolving
    case decisionMaking
    case conflict
    case unexpected
    case awkwardFunny

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everydayLife: return "Everyday life"
        case .travel: return "Travel"
        case .social: return "Social"
        case .problemSolving: return "Problem solving"
        case .decisionMaking: return "Decision making"
        case .conflict: return "Conflict"
        case .unexpected: return "Unexpected situations"
        case .awkwardFunny: return "Awkward / funny"
        }
    }

    var promptGuidance: String {
        switch self {
        case .everydayLife:
            return "Normal situations like shopping, commuting, restaurants, appointments, errands, or home life. Vary the place each time; do not default to a famous city."
        case .travel:
            return """
            A real traveler-to-staff or traveler-to-local exchange on a trip in China, not a vacation recap.
            Rotate widely among cities AND among place types with no city named: stations, airports, hotels, taxis, restaurants, attractions, ticket windows, night markets, hostels, ferries, cable cars.
            Do not default to Beijing or Shanghai. Most situations should not start with 在北京 or 在上海.
            """
        case .social:
            return "Friends, coworkers, relatives, meeting people, or invitations. Vary the gathering and the relationship."
        case .problemSolving:
            return "Something goes wrong and the learner needs to handle it. Vary what broke and where."
        case .decisionMaking:
            return "Compare options, make a choice, and explain why. Vary the kind of choice."
        case .conflict:
            return "Disagreement, complaint, misunderstanding, or negotiation. Vary the other person and the setting."
        case .unexpected:
            return "Plans change or new information appears. Vary the surprise and where it happens."
        case .awkwardFunny:
            return "Socially uncomfortable or memorable situations. Vary the mishap; keep it light, not cruel."
        }
    }

    /// Concrete scene the model must use, so it does not fall back to Beijing/Shanghai textbook defaults.
    var sceneBank: [String] {
        switch self {
        case .everydayLife:
            return [
                "a neighborhood wet market in the morning",
                "a parcel locker in an apartment courtyard",
                "a community clinic waiting room",
                "a 24-hour convenience store at 11pm",
                "the office pantry microwave line",
                "a hair salon",
                "a shared laundry room in an apartment building",
                "a pharmacy counter",
                "the school gate at pickup time",
                "a park chess table",
                "a gym front desk",
                "a bank number-ticket machine",
                "an elevator stuck between floors for a moment",
                "a downstairs breakfast stall",
                "a post office queue",
                "a neighborhood committee notice board"
            ]
        case .travel:
            return [
                "Chengdu East railway station ticket window",
                "a high-speed train platform",
                "airport security, water bottle too full",
                "a hotel front desk after a delayed flight",
                "a taxi that may be taking a longer route",
                "West Lake boat ticket booth in Hangzhou",
                "a food stall in Xi'an Muslim Quarter",
                "a Chongqing hot pot restaurant warning about spice",
                "the Gulangyu ferry terminal in Xiamen",
                "the Zhangjiajie cable car line",
                "a night market stall that cannot break a large bill",
                "a luggage carousel where the bag has not appeared",
                "customs inspection with a food item in the suitcase",
                "a hostel that cannot find the reservation",
                "a canal-side inn in Suzhou",
                "a beach umbrella rental in Qingdao",
                "the ice-festival entrance in Harbin",
                "the Li River cruise dock in Guilin",
                "asking for directions on a plaza in Lhasa",
                "timed-entry tickets at Dunhuang Mogao Caves",
                "a Huangshan trailhead in the fog",
                "leftover-ticket window at Kunming railway station",
                "Shenzhen metro customer service",
                "a souvenir shop near Nanjing Confucius Temple",
                "an e-bike rental in Yangshuo countryside",
                "a scenic-area bathroom that requires scanning a code",
                "a convenience store near the station, looking for a SIM card",
                "the dining car on a long-distance train",
                "a museum cloakroom that will not take a backpack",
                "Urumqi night bazaar asking about prices",
                "Sanya hotel checkout with a wrong minibar charge",
                "a highway rest stop looking for a restroom",
                "Luoyang grottoes ticket office in the rain",
                "a Didi pickup point the driver cannot find",
                "an airport gate change announced only in Chinese",
                "a shared kitchen in a youth hostel",
                "a tea house in a small town",
                "a mountain temple parking lot",
                "Guangzhou Baiyun Airport check-in with an overweight bag",
                "Wuhan Yellow Crane Tower timed tickets sold out until afternoon"
            ]
        case .social:
            return [
                "a coworker leaving-party at a hot pot restaurant",
                "a WeChat group trying to pick a dinner time",
                "karaoke after work",
                "tea with relatives who ask too many questions",
                "a park picnic with friends",
                "a wedding banquet table",
                "meeting a friend's friend for the first time",
                "a mahjong table at someone's home",
                "a campus club signup desk",
                "a roommate's friends filling the living room",
                "a birthday cake in a small restaurant",
                "a video call with family while traveling"
            ]
        case .problemSolving:
            return [
                "a washing machine that stopped mid-cycle",
                "a food delivery that is the wrong order",
                "lost keys at the building gate",
                "Wi-Fi down in a cafe that needs a QR code to order",
                "a missing package at the parcel locker",
                "a phone at 3% battery, needing a charger",
                "a shared bike that will not unlock",
                "a hotel room air-conditioner that will not turn on",
                "a train seat that is already taken",
                "a restaurant that cannot find the reservation name"
            ]
        case .decisionMaking:
            return [
                "two restaurants with a line forming at both",
                "take a taxi or the subway with only 20 minutes",
                "buy the expensive ticket now or wait for a later slot",
                "two apartments, one cheaper but farther",
                "stay another night or leave early tomorrow",
                "spicy or not-spicy, and someone at the table cannot eat spice",
                "a group chat choosing between hiking and a museum",
                "upgrade a train ticket or keep the hard seat"
            ]
        case .conflict:
            return [
                "a noisy neighbor after midnight",
                "a bill that looks too high at a restaurant",
                "a friend who is always late",
                "a group project where one person did not do their part",
                "a landlord about a repair that never happened",
                "a taxi driver and a fare disagreement",
                "a crowded subway and someone pushing",
                "a shop refusing a return without a receipt"
            ]
        case .unexpected:
            return [
                "sudden heavy rain with no umbrella",
                "a train cancelled on the departure board",
                "a store closed for a private event",
                "tickets sold out when you reach the window",
                "a surprise guest at the door",
                "the meeting moved to a different building",
                "a power cut in the apartment",
                "the last bus already left"
            ]
        case .awkwardFunny:
            return [
                "walking into the wrong restroom",
                "mishearing someone's name and repeating it wrong",
                "ordering far too much food at a restaurant",
                "a toast at a dinner where you do not know the custom",
                "a compliment that came out as an insult",
                "waving at a stranger who looks like a friend",
                "a WeChat voice message sent to the wrong group",
                "sitting at a reserved table by mistake"
            ]
        }
    }

    func randomScene(excluding last: String? = nil) -> String {
        let options = sceneBank.filter { $0 != last }
        return (options.isEmpty ? sceneBank : options).randomElement() ?? title
    }
}

enum MissionPromptVariety {
    static let situationShapes: [String] = [
        "Address the learner as 你. Do not introduce a named third person.",
        "The situation is a notice, sign, announcement, menu, or ticket board. No character names.",
        "The situation is a WeChat message or SMS the learner just received. Quote it briefly.",
        "The situation is a phone call that just connected, or one ring of a call.",
        "Write two short spoken turns that already happened (A / B). The learner continues the exchange.",
        "First person: the learner just did something and now needs the next step.",
        "A clerk, driver, roommate, or stranger is speaking to the learner. Give their line. Use a role, not a stock name.",
        "Describe only what the learner can see or hear right now. No backstory and no named protagonists.",
        "A plan, reservation, or closing-time conflict. No personal names.",
        "Someone just asked the learner a short question. Do not name them unless a role is needed (服务员, 司机, 同学).",
        "The situation is a group chat, a note on the fridge, or a classroom instruction.",
        "The learner overhears one line nearby and has to respond or act."
    ]

    static let taskShapes: [String] = [
        "Ask one natural question.",
        "Give a short spoken reply as if talking now.",
        "Leave a WeChat message of one or two sentences.",
        "Politely refuse, delay, or say you cannot.",
        "Confirm or repeat the key information.",
        "Make a request at a counter, window, or desk.",
        "Choose one option and say why.",
        "Correct a small misunderstanding.",
        "Tell a friend what you need, not the staff.",
        "Order, book, or ask for something specific.",
        "Apologize and offer a next step.",
        "Explain a time, place, or quantity in one short reply."
    ]
}

enum MissionFocus: String, CaseIterable, Codable, Sendable {
    case vocabulary
    case grammar

    var sectionTitle: String {
        switch self {
        case .vocabulary: return "Target word"
        case .grammar: return "Target grammar"
        }
    }

    var usedCorrectlyLabel: String {
        switch self {
        case .vocabulary: return "Target word used correctly"
        case .grammar: return "Target grammar used correctly"
        }
    }
}

struct HSKRange: Equatable, Sendable {
    static let levels = 1...6
    static let defaultLevel = 3
    static let `default` = HSKRange(min: defaultLevel, max: defaultLevel)

    var min: Int
    var max: Int

    var title: String { "HSK \(min)–\(max)" }

    init(min: Int, max: Int) {
        let clampedMin = min.clamped(to: Self.levels)
        let clampedMax = max.clamped(to: Self.levels)
        self.min = Swift.min(clampedMin, clampedMax)
        self.max = Swift.max(clampedMin, clampedMax)
    }

    func updatingMin(_ newMin: Int) -> HSKRange {
        let clamped = newMin.clamped(to: Self.levels)
        return HSKRange(min: clamped, max: Swift.max(clamped, max))
    }

    func updatingMax(_ newMax: Int) -> HSKRange {
        let clamped = newMax.clamped(to: Self.levels)
        return HSKRange(min: Swift.min(min, clamped), max: clamped)
    }

    func contains(_ level: Int) -> Bool {
        (min...max).contains(level)
    }
}

struct DailyMissionTargetWord: Sendable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    let focus: MissionFocus

    init(hanzi: String, pinyin: String, meaning: String, focus: MissionFocus) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        self.focus = focus
    }

    init(card: Flashcard) {
        self.init(
            hanzi: card.hanzi,
            pinyin: card.pinyin,
            meaning: card.displayEnglish,
            focus: card.cardKind == .grammar ? .grammar : .vocabulary
        )
    }
}

struct MissionWord: Sendable, Codable, Hashable {
    var hanzi: String
    var pinyin: String
    var english: String

    var isTappable: Bool {
        hanzi.contains { $0.isCJK }
    }

    var hasDetails: Bool {
        !pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(hanzi: String, pinyin: String, english: String) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.english = english
    }

    enum CodingKeys: String, CodingKey {
        case hanzi, pinyin, english
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hanzi = try container.decode(String.self, forKey: .hanzi)
        pinyin = try container.decodeIfPresent(String.self, forKey: .pinyin) ?? ""
        english = try container.decodeIfPresent(String.self, forKey: .english) ?? ""
    }
}

struct DailyMission: Sendable, Decodable {
    var focus: MissionFocus
    var hanzi: String
    var pinyin: String
    var meaning: String
    var grammarHanzi: String
    var grammarPinyin: String
    var grammarMeaning: String
    let situationChinese: String
    let situationPinyin: String
    let situationEnglish: String
    let taskChinese: String
    let taskPinyin: String
    let taskEnglish: String
    let situationWords: [MissionWord]
    let taskWords: [MissionWord]

    var hasGrammarTarget: Bool {
        !grammarHanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var situationTokens: [MissionWord] {
        ChineseWordSegmenter.resolvedWords(sentence: situationChinese, provided: situationWords)
    }

    var taskTokens: [MissionWord] {
        ChineseWordSegmenter.resolvedWords(sentence: taskChinese, provided: taskWords)
    }

    enum CodingKeys: String, CodingKey {
        case focus, hanzi, pinyin, meaning
        case grammarHanzi, grammarPinyin, grammarMeaning
        case situationChinese, situationPinyin, situationEnglish, situationWords
        case taskChinese, taskPinyin, taskEnglish, taskWords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try? container.decodeIfPresent(String.self, forKey: .focus),
           let decoded = MissionFocus(rawValue: raw) {
            focus = decoded
        } else {
            focus = .vocabulary
        }
        hanzi = try container.decode(String.self, forKey: .hanzi)
        pinyin = container.decodeFlexibleString(.pinyin)
        meaning = container.decodeFlexibleString(.meaning)
        grammarHanzi = container.decodeFlexibleString(.grammarHanzi)
        grammarPinyin = container.decodeFlexibleString(.grammarPinyin)
        grammarMeaning = container.decodeFlexibleString(.grammarMeaning)
        situationChinese = container.decodeFlexibleString(.situationChinese)
        situationPinyin = container.decodeFlexibleString(.situationPinyin)
        situationEnglish = container.decodeFlexibleString(.situationEnglish)
        taskChinese = container.decodeFlexibleString(.taskChinese)
        taskPinyin = container.decodeFlexibleString(.taskPinyin)
        taskEnglish = container.decodeFlexibleString(.taskEnglish)
        situationWords = (try? container.decode([MissionWord].self, forKey: .situationWords)) ?? []
        taskWords = (try? container.decode([MissionWord].self, forKey: .taskWords)) ?? []
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(_ key: Key) -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        return ""
    }
}

struct DailyMissionEvaluation: Sendable {
    let success: Bool
    let meaning: Int
    let grammar: Int
    let naturalness: Int
    let targetWordUsedCorrectly: Bool
    let targetGrammarUsedCorrectly: Bool
    let feedback: String
    let naturalChinese: String
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
