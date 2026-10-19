import Foundation

/// What the concierge and capture boxes can do with a line of text.
public enum CaptureKind: String, Codable, Sendable {
    case task
    case reminder
    case waitingOn
}

/// A capture waiting to reach Notion. Lives on the Mac until the cloud is on.
public struct Capture: Codable, Hashable, Identifiable, Sendable {
    public enum Status: String, Codable, Sendable {
        case queued
        case sent
    }

    public var id: String
    public var text: String
    public var title: String
    public var kind: CaptureKind
    public var createdAt: Date
    public var due: Date?
    public var projectID: String?
    public var status: Status

    public init(id: String = UUID().uuidString, text: String, title: String, kind: CaptureKind, createdAt: Date, due: Date? = nil, projectID: String? = nil, status: Status = .queued) {
        self.id = id
        self.text = text
        self.title = title
        self.kind = kind
        self.createdAt = createdAt
        self.due = due
        self.projectID = projectID
        self.status = status
    }
}

/// Reads a quick capture like "chase officials roster thursday".
public struct ParsedCapture: Equatable, Sendable {
    /// "Chase officials roster".
    public var title: String
    /// Start of the day it's due, if a day was mentioned.
    public var due: Date?
    /// "officials roster": the title without the leading verb.
    public var searchTerm: String
}

public enum CaptureParser {
    static let weekdayWords: [String: Int] = [
        "sunday": 1, "sun": 1,
        "monday": 2, "mon": 2,
        "tuesday": 3, "tue": 3, "tues": 3,
        "wednesday": 4, "wed": 4,
        "thursday": 5, "thu": 5, "thur": 5, "thurs": 5,
        "friday": 6, "fri": 6,
        "saturday": 7, "sat": 7,
    ]

    static let linkWords: Set<String> = ["by", "on", "due", "before", "for"]

    static let leadingVerbs: Set<String> = [
        "chase", "call", "email", "text", "ring", "send", "book", "check", "ask", "review",
        "draft", "write", "finish", "follow", "pay", "buy", "remind", "sort", "fix", "update",
        "confirm", "organise", "organize", "prep", "prepare", "read", "find", "look",
    ]

    public static func parse(_ text: String, now: Date, clock: LobbyClock) -> ParsedCapture {
        var words = text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var due: Date?

        // Find a day word anywhere, then drop it and any "by"/"on" in front.
        if let index = words.indices.last(where: { dayOffset(for: words[$0].lowercased(), next: word(after: $0, in: words), now: now, clock: clock) != nil }) {
            let lower = words[index].lowercased()
            let following = index + 1 < words.count ? words[index + 1].lowercased() : nil
            due = dayOffset(for: lower, next: following, now: now, clock: clock)
            var removeRange = index...index
            if lower == "next", following == "week" { removeRange = index...(index + 1) }
            words.removeSubrange(removeRange)
            if index > 0, linkWords.contains(words[index - 1].lowercased()) {
                words.remove(at: index - 1)
            }
        }

        let title = words.joined(separator: " ")
        var searchWords = words
        if let first = searchWords.first, leadingVerbs.contains(first.lowercased()), searchWords.count > 1 {
            searchWords.removeFirst()
            if searchWords.first?.lowercased() == "up" { searchWords.removeFirst() }
        }
        return ParsedCapture(
            title: title.prefix(1).uppercased() + title.dropFirst(),
            due: due,
            searchTerm: searchWords.joined(separator: " ").lowercased()
        )
    }

    private static func word(after i: Int, in words: [String]) -> String? {
        i + 1 < words.count ? words[i + 1].lowercased() : nil
    }

    private static func dayOffset(for word: String, next: String?, now: Date, clock: LobbyClock) -> Date? {
        let today = clock.startOfDay(now)
        switch word {
        case "today", "tonight": return today
        case "tomorrow", "tmrw": return clock.addingDays(1, to: today)
        case "next" where next == "week": return clock.next(weekday: 2, after: now)
        default:
            guard let weekday = weekdayWords[word] else { return nil }
            return clock.next(weekday: weekday, after: now, includingToday: true)
        }
    }
}

/// Guesses which Notion project a capture belongs to from the words they share.
public enum ProjectMatcher {
    static let stopWords: Set<String> = ["the", "and", "for", "with", "from", "this", "that", "about", "into", "meet"]

    static func keywords(_ text: String) -> Set<String> {
        Set(text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 4 && !stopWords.contains($0) })
    }

    public static func match(_ text: String, in projects: [Project]) -> Project? {
        let words = keywords(text)
        let scored = projects
            .map { ($0, keywords($0.name + " " + $0.nextStep).intersection(words).count) }
            .filter { $0.1 > 0 }
        return scored.max { $0.1 < $1.1 }?.0
    }
}
