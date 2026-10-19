import Foundation

// MARK: - F1

public struct F1Team: Codable, Hashable, Identifiable, Sendable {
    /// Jolpica's constructorId, so live data lines up with the picker.
    public var id: String
    public var name: String
    public var colorHex: String
    public var drivers: [String]

    public init(id: String, name: String, colorHex: String, drivers: [String]) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.drivers = drivers
    }

    /// All 11 teams on the 2026 grid, in the order the picker shows them.
    /// Line-ups are a starting point; live data from Jolpica replaces them.
    public static let all: [F1Team] = [
        F1Team(id: "alpine", name: "Alpine", colorHex: "#0093CC", drivers: ["Gasly", "Colapinto"]),
        F1Team(id: "aston_martin", name: "Aston Martin", colorHex: "#229971", drivers: ["Alonso", "Stroll"]),
        F1Team(id: "audi", name: "Audi", colorHex: "#FF4D2E", drivers: ["Hülkenberg", "Bortoleto"]),
        F1Team(id: "cadillac", name: "Cadillac", colorHex: "#C9CDD2", drivers: ["Pérez", "Bottas"]),
        F1Team(id: "ferrari", name: "Ferrari", colorHex: "#E8002D", drivers: ["Leclerc", "Hamilton"]),
        F1Team(id: "haas", name: "Haas", colorHex: "#B6BABD", drivers: ["Ocon", "Bearman"]),
        F1Team(id: "mclaren", name: "McLaren", colorHex: "#FF8000", drivers: ["Norris", "Piastri"]),
        F1Team(id: "mercedes", name: "Mercedes", colorHex: "#27F4D2", drivers: ["Russell", "Antonelli"]),
        F1Team(id: "rb", name: "Racing Bulls", colorHex: "#6692FF", drivers: ["Lawson", "Lindblad"]),
        F1Team(id: "red_bull", name: "Red Bull", colorHex: "#3671C6", drivers: ["Verstappen", "Hadjar"]),
        F1Team(id: "williams", name: "Williams", colorHex: "#64C4FF", drivers: ["Albon", "Sainz"]),
    ]

    public static let mclaren = all.first { $0.id == "mclaren" }!

    public static func team(id: String) -> F1Team? {
        all.first { $0.id == id }
    }
}

public enum F1SessionKind: String, Codable, Sendable {
    case practice1, practice2, practice3, sprintQualifying, sprint, qualifying, race

    public var label: String {
        switch self {
        case .practice1: return "Practice 1"
        case .practice2: return "Practice 2"
        case .practice3: return "Practice 3"
        case .sprintQualifying: return "Sprint qualifying"
        case .sprint: return "Sprint"
        case .qualifying: return "Qualifying"
        case .race: return "Race"
        }
    }

    /// Sessions whose outcome is a spoiler.
    public var producesResult: Bool {
        switch self {
        case .practice1, .practice2, .practice3: return false
        default: return true
        }
    }
}

public struct F1Session: Codable, Hashable, Sendable {
    public var kind: F1SessionKind
    public var start: Date
    /// When Lobby wakes him, if it does.
    public var alarm: Date?

    public init(kind: F1SessionKind, start: Date, alarm: Date? = nil) {
        self.kind = kind
        self.start = start
        self.alarm = alarm
    }
}

public struct F1Weekend: Codable, Hashable, Identifiable, Sendable {
    /// "2026-18": season and round.
    public var id: String
    public var name: String
    /// "US Grand Prix", for tight spaces.
    public var shortName: String
    /// "Austin", the hero watermark.
    public var locality: String
    public var sessions: [F1Session]

    public init(id: String, name: String, shortName: String, locality: String, sessions: [F1Session]) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.locality = locality
        self.sessions = sessions.sorted { $0.start < $1.start }
    }

    public var firstSession: F1Session? { sessions.first }
    public var race: F1Session? { sessions.first { $0.kind == .race } }
    public var qualifying: F1Session? { sessions.first { $0.kind == .qualifying } }

    public func nextSession(after now: Date) -> F1Session? {
        sessions.first { $0.start > now }
    }

    /// The latest session with a result that has started by `now`.
    public func latestResultSession(at now: Date) -> F1Session? {
        sessions.last { $0.kind.producesResult && $0.start <= now }
    }
}

/// Race week runs from the start of the season to the last race; off-season after that.
public enum F1Phase: String, Codable, Sendable {
    case raceWeek
    case offSeason
}

public struct F1Calendar: Codable, Hashable, Sendable {
    public var weekends: [F1Weekend]

    public init(weekends: [F1Weekend]) {
        self.weekends = weekends.sorted { ($0.firstSession?.start ?? .distantPast) < ($1.firstSession?.start ?? .distantPast) }
    }

    /// The weekend still to finish: the one under way, else the next to start.
    public func current(at now: Date) -> F1Weekend? {
        weekends.first { weekend in
            guard let race = weekend.race else { return false }
            return race.start.addingTimeInterval(3 * 3600) > now
        }
    }

    /// The most recent weekend with a result already out (or under way).
    public func latestWithResult(at now: Date) -> F1Weekend? {
        weekends.last { $0.latestResultSession(at: now) != nil }
    }

    public func phase(at now: Date) -> F1Phase {
        current(at: now) == nil ? .offSeason : .raceWeek
    }
}

public struct DriverStanding: Codable, Hashable, Sendable {
    public var position: Int
    public var driver: String
    public var teamID: String
    public var points: Double

    public init(position: Int, driver: String, teamID: String, points: Double) {
        self.position = position
        self.driver = driver
        self.teamID = teamID
        self.points = points
    }
}

// MARK: - AFL

public struct AFLClub: Codable, Hashable, Identifiable, Sendable {
    /// Squiggle's team id.
    public var id: Int
    public var name: String
    /// A colour that glows on black. Approximate, as the design notes.
    public var colorHex: String
    public var nickname: String

    public init(id: Int, name: String, colorHex: String, nickname: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.nickname = nickname
    }

    public static let portAdelaide = AFLClub(id: 13, name: "Port Adelaide", colorHex: "#00A9C5", nickname: "Power")

    /// Port first, then the rest alphabetically.
    public static let all: [AFLClub] = [
        portAdelaide,
        AFLClub(id: 1, name: "Adelaide", colorHex: "#E21937", nickname: "Crows"),
        AFLClub(id: 2, name: "Brisbane", colorHex: "#A30046", nickname: "Lions"),
        AFLClub(id: 3, name: "Carlton", colorHex: "#3A6FC4", nickname: "Blues"),
        AFLClub(id: 4, name: "Collingwood", colorHex: "#E8E8E8", nickname: "Magpies"),
        AFLClub(id: 5, name: "Essendon", colorHex: "#CC2031", nickname: "Bombers"),
        AFLClub(id: 6, name: "Fremantle", colorHex: "#6B3FA8", nickname: "Dockers"),
        AFLClub(id: 7, name: "Geelong", colorHex: "#4A7FC1", nickname: "Cats"),
        AFLClub(id: 8, name: "Gold Coast", colorHex: "#E02112", nickname: "Suns"),
        AFLClub(id: 9, name: "GWS", colorHex: "#F47920", nickname: "Giants"),
        AFLClub(id: 10, name: "Hawthorn", colorHex: "#FBBF15", nickname: "Hawks"),
        AFLClub(id: 11, name: "Melbourne", colorHex: "#DE0316", nickname: "Demons"),
        AFLClub(id: 12, name: "North Melbourne", colorHex: "#2F6FDE", nickname: "Kangaroos"),
        AFLClub(id: 14, name: "Richmond", colorHex: "#FED102", nickname: "Tigers"),
        AFLClub(id: 15, name: "St Kilda", colorHex: "#ED0F05", nickname: "Saints"),
        AFLClub(id: 16, name: "Sydney", colorHex: "#ED171F", nickname: "Swans"),
        AFLClub(id: 17, name: "West Coast", colorHex: "#F2A900", nickname: "Eagles"),
        AFLClub(id: 18, name: "Western Bulldogs", colorHex: "#2D6BE5", nickname: "Bulldogs"),
    ]

    public static func club(id: Int) -> AFLClub? {
        all.first { $0.id == id }
    }
}

// MARK: - News

public struct NewsItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var source: String
    public var title: String
    public var url: String?
    public var published: Date
    /// Set by the cloud when a headline might give a result away.
    public var mayContainResult: Bool
    /// Team ids (F1) or club ids as strings (AFL) the headline is about.
    public var tags: [String]

    public init(id: String, source: String, title: String, url: String? = nil, published: Date, mayContainResult: Bool = false, tags: [String] = []) {
        self.id = id
        self.source = source
        self.title = title
        self.url = url
        self.published = published
        self.mayContainResult = mayContainResult
        self.tags = tags
    }

    /// His team's headlines first, then newest first.
    public static func ordered(_ items: [NewsItem], favouriteTag: String) -> [NewsItem] {
        items.sorted { a, b in
            let aFav = a.tags.contains(favouriteTag), bFav = b.tags.contains(favouriteTag)
            if aFav != bFav { return aFav }
            return a.published > b.published
        }
    }
}
