import Foundation

/// The pastel and accent fills cards and avatars use.
public enum Tint: String, Codable, Sendable {
    case lime, lilac, sky, mint, peach
}

public struct Meeting: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var start: Date
    public var minutes: Int
    public var location: String?
    /// Extra context, like "Held by Lobby for the COTY sheet".
    public var note: String?

    public init(id: String, title: String, start: Date, minutes: Int, location: String? = nil, note: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.minutes = minutes
        self.location = location
        self.note = note
    }

    public var end: Date { start.addingTimeInterval(TimeInterval(minutes * 60)) }

    /// The meeting on now, else the next one to start.
    public static func nextUp(in meetings: [Meeting], at now: Date) -> Meeting? {
        meetings.filter { $0.end > now }.min { $0.start < $1.start }
    }
}

public struct TaskItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var done: Bool

    public init(id: String, title: String, done: Bool = false) {
        self.id = id
        self.title = title
        self.done = done
    }
}

public struct WaitingOn: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var initials: String
    public var what: String
    public var since: Date
    public var tint: Tint
    public var nudgedAt: Date?
    /// When to flag it if nothing has come back.
    public var flagAfter: Date?

    public init(id: String, initials: String, what: String, since: Date, tint: Tint, nudgedAt: Date? = nil, flagAfter: Date? = nil) {
        self.id = id
        self.initials = initials
        self.what = what
        self.since = since
        self.tint = tint
        self.nudgedAt = nudgedAt
        self.flagAfter = flagAfter
    }

    /// Waiting four days or more reads as overdue.
    public func isStale(at now: Date, clock: LobbyClock) -> Bool {
        if let flagAfter, now >= flagAfter { return true }
        return clock.calendarDays(from: since, to: now) >= 4
    }
}

public struct Project: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var nextStep: String

    public init(id: String, name: String, nextStep: String) {
        self.id = id
        self.name = name
        self.nextStep = nextStep
    }
}

public struct Trip: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var flight: String
    public var departs: Date

    public init(id: String, name: String, flight: String, departs: Date) {
        self.id = id
        self.name = name
        self.flight = flight
        self.departs = departs
    }
}

public struct BodySummary: Codable, Hashable, Sendable {
    public struct Chip: Codable, Hashable, Sendable {
        public var text: String
        public var highlighted: Bool

        public init(text: String, highlighted: Bool = false) {
            self.text = text
            self.highlighted = highlighted
        }
    }

    public var chips: [Chip]
    public var tomorrow: String

    public init(chips: [Chip], tomorrow: String) {
        self.chips = chips
        self.tomorrow = tomorrow
    }
}

public struct FleetSummary: Codable, Hashable, Sendable {
    public var flown: Int
    public var spotted: Int
    public var total: Int
    public var latest: String

    public init(flown: Int, spotted: Int, total: Int, latest: String) {
        self.flown = flown
        self.spotted = spotted
        self.total = total
        self.latest = latest
    }
}

public struct NowPlaying: Codable, Hashable, Sendable {
    public var title: String
    public var source: String
    public var isPlaying: Bool

    public init(title: String, source: String, isPlaying: Bool) {
        self.title = title
        self.source = source
        self.isPlaying = isPlaying
    }
}

public enum WeeklyLog {
    /// The log is written for him at 3pm on Friday.
    public static func nextReady(after date: Date, clock: LobbyClock) -> Date {
        let fridayThisWeek = clock.next(weekday: 6, after: date, includingToday: true)
        let ready = clock.date(on: fridayThisWeek, hour: 15)
        if ready > date { return ready }
        return clock.date(on: clock.next(weekday: 6, after: date), hour: 15)
    }

    /// From 3pm Friday through the weekend the week's log is there to read.
    public static func isReady(at date: Date, clock: LobbyClock) -> Bool {
        switch clock.weekday(date) {
        case 6: return date >= clock.date(on: date, hour: 15)
        case 7, 1: return true
        default: return false
        }
    }
}
