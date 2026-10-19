import Foundation

public enum QuizTopic: String, Codable, CaseIterable, Sendable {
    case aviation, f1, port
}

public struct QuizQuestion: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var topic: QuizTopic
    public var prompt: String
    public var options: [String]
    public var answer: String
    /// Shown after a right answer: "It flies as Nancy-Bird Walton."
    public var note: String

    public init(id: String, topic: QuizTopic, prompt: String, options: [String], answer: String, note: String) {
        self.id = id
        self.topic = topic
        self.prompt = prompt
        self.options = options
        self.answer = answer
        self.note = note
    }
}

/// Three questions a day: one aviation, one F1, one Port.
public struct QuizBank: Sendable {
    public var questions: [QuizQuestion]

    public init(questions: [QuizQuestion]) {
        self.questions = questions
    }

    /// The same three for everyone asking on the same day.
    public func daily(for dayKey: String) -> [QuizQuestion] {
        QuizTopic.allCases.compactMap { topic in
            let pool = questions.filter { $0.topic == topic }
            guard !pool.isEmpty else { return nil }
            return pool[Self.stableHash(dayKey + topic.rawValue) % pool.count]
        }
    }

    /// `hashValue` changes every launch, so roll our own: FNV-1a, then a
    /// splitmix finish so small pools (three questions) still get mixed well.
    static func stableHash(_ text: String) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        hash ^= hash >> 30
        hash = hash &* 0xbf58_476d_1ce4_e5b9
        hash ^= hash >> 27
        hash = hash &* 0x94d0_49bb_1331_11eb
        hash ^= hash >> 31
        return Int(hash >> 1)
    }

    /// A small starter bank. The cloud writes fresh ones from his own world later.
    public static let starter = QuizBank(questions: [
        QuizQuestion(id: "av-oqa", topic: .aviation, prompt: "What type of aircraft is VH-OQA?",
                     options: ["A380", "787-9", "A330"], answer: "A380",
                     note: "It flies as Nancy-Bird Walton."),
        QuizQuestion(id: "av-per-lhr", topic: .aviation, prompt: "Which Qantas type flies Perth to London nonstop?",
                     options: ["787-9", "A380", "A330"], answer: "787-9",
                     note: "QF9, about 17 hours in the air."),
        QuizQuestion(id: "av-sunrise", topic: .aviation, prompt: "Which aircraft is Qantas buying for Project Sunrise?",
                     options: ["A350-1000", "777X", "A380"], answer: "A350-1000",
                     note: "Sydney to London nonstop, with an extra fuel tank."),
        QuizQuestion(id: "f1-cota", topic: .f1, prompt: "Which circuit hosts the United States Grand Prix?",
                     options: ["Circuit of the Americas", "Indianapolis", "Watkins Glen"], answer: "Circuit of the Americas",
                     note: "Austin, Texas."),
        QuizQuestion(id: "f1-grid", topic: .f1, prompt: "How many teams are on the 2026 grid?",
                     options: ["10", "11", "12"], answer: "11",
                     note: "Cadillac made it eleven."),
        QuizQuestion(id: "f1-points", topic: .f1, prompt: "How many points does a Grand Prix win score?",
                     options: ["20", "25", "26"], answer: "25",
                     note: "Second gets 18, third 15."),
        QuizQuestion(id: "port-joined", topic: .port, prompt: "What year did Port Adelaide join the AFL?",
                     options: ["1990", "1997", "2004"], answer: "1997",
                     note: "Six years after the Crows."),
        QuizQuestion(id: "port-flag", topic: .port, prompt: "Which year did Port win its AFL premiership?",
                     options: ["2004", "2007", "2014"], answer: "2004",
                     note: "Beat Brisbane in the grand final."),
        QuizQuestion(id: "port-coach", topic: .port, prompt: "Who coached Port to the 2004 flag?",
                     options: ["Mark Williams", "Ken Hinkley", "John Cahill"], answer: "Mark Williams",
                     note: "The club's first AFL flag, in its eighth season."),
    ])
}

/// Answers by day, and the streak that comes from them.
///
/// A day counts towards the streak when every answer given that day was right.
/// One wrong answer and the streak resets tomorrow.
public struct QuizLog: Codable, Equatable, Sendable {
    /// Day key to answers in order, true for right.
    public var days: [String: [Bool]]

    public init(days: [String: [Bool]] = [:]) {
        self.days = days
    }

    public func answers(on dayKey: String) -> [Bool] {
        days[dayKey] ?? []
    }

    public mutating func record(correct: Bool, on dayKey: String) {
        days[dayKey, default: []].append(correct)
    }

    public func streak(at date: Date, clock: LobbyClock) -> Int {
        var count = 0
        let today = answers(on: clock.dayKey(date))
        if !today.isEmpty && !today.contains(false) { count += 1 }
        var day = clock.addingDays(-1, to: date)
        while let answers = days[clock.dayKey(day)], !answers.isEmpty, !answers.contains(false) {
            count += 1
            day = clock.addingDays(-1, to: day)
        }
        return count
    }

    /// Keep the last couple of months so the log doesn't grow forever.
    public mutating func prune(keepingDaysFrom date: Date, clock: LobbyClock) {
        let cutoff = clock.dayKey(clock.addingDays(-60, to: date))
        days = days.filter { $0.key >= cutoff }
    }
}
