import Foundation

/// The documents the cloud writes to Firestore, as `functions/src` shapes them.
/// Every date is an ISO 8601 string, so these decode from plain JSON.
public enum Cloud {
    /// Decodes the functions' output. Accepts dates with or without fractional seconds.
    public static let decoder: JSONDecoder = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = withFraction.date(from: text) ?? plain.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an ISO 8601 date: \(text)"))
        }
        return decoder
    }()

    public static func decode<T: Decodable>(_ type: T.Type, from json: Data) throws -> T {
        try decoder.decode(type, from: json)
    }

    // MARK: sports/f1Calendar

    public struct F1CalendarDoc: Codable, Sendable {
        public struct Session: Codable, Sendable {
            public var kind: String
            public var start: Date
        }

        public struct Weekend: Codable, Sendable {
            public var id: String
            public var season: Int
            public var round: Int
            public var name: String
            public var shortName: String
            public var locality: String
            public var sessions: [Session]
        }

        public var season: Int
        public var weekends: [Weekend]

        /// Alarms follow the mock-up: qualifying at the start, race 15 minutes before.
        public func calendar() -> F1Calendar {
            F1Calendar(weekends: weekends.map { weekend in
                F1Weekend(
                    id: weekend.id,
                    name: weekend.name,
                    shortName: weekend.shortName,
                    locality: weekend.locality,
                    sessions: weekend.sessions.compactMap { session in
                        guard let kind = F1SessionKind(rawValue: session.kind) else { return nil }
                        let alarm: Date?
                        switch kind {
                        case .qualifying: alarm = session.start
                        case .race: alarm = session.start.addingTimeInterval(-15 * 60)
                        default: alarm = nil
                        }
                        return F1Session(kind: kind, start: session.start, alarm: alarm)
                    }
                )
            })
        }
    }

    // MARK: sports/f1Standings

    public struct F1StandingsDoc: Codable, Sendable {
        public struct Row: Codable, Sendable {
            public var position: Int
            public var driver: String
            public var teamID: String
            public var points: Double
        }

        public var round: Int
        public var drivers: [Row]

        public func standings() -> [DriverStanding] {
            drivers.map { DriverStanding(position: $0.position, driver: $0.driver, teamID: $0.teamID, points: $0.points) }
        }
    }

    // MARK: sports/f1Latest

    public struct F1LatestDoc: Codable, Sendable {
        public struct Result: Codable, Sendable {
            public var weekendID: String
            public var raceName: String
            public var topThree: [String]
        }

        public var race: Result?
        public var qualifying: Result?
    }

    // MARK: news/f1 and news/afl

    public struct NewsDoc: Codable, Sendable {
        public struct Item: Codable, Sendable {
            public var id: String
            public var source: String
            public var title: String
            public var url: String?
            public var published: Date
            public var mayContainResult: Bool
            public var tags: [String]
        }

        public var items: [Item]
        public var failedFeeds: [String]?

        public func news() -> [NewsItem] {
            items.map {
                NewsItem(id: $0.id, source: $0.source, title: $0.title, url: $0.url, published: $0.published,
                         mayContainResult: $0.mayContainResult, tags: $0.tags)
            }
        }
    }

    // MARK: sports/afl

    public struct AFLDoc: Codable, Sendable {
        public struct Game: Codable, Sendable {
            public var id: Int
            public var round: Int
            public var roundName: String
            public var homeID: Int?
            public var awayID: Int?
            public var home: String
            public var away: String
            public var start: Date
            public var venue: String
            public var homeScore: Int?
            public var awayScore: Int?
            public var complete: Int
            public var status: String?

            public func involves(_ clubID: Int) -> Bool {
                homeID == clubID || awayID == clubID
            }

            public func opponent(of clubID: Int) -> String {
                homeID == clubID ? away : home
            }
        }

        public struct LadderRow: Codable, Sendable {
            public var rank: Int
            public var teamID: Int
            public var name: String
            public var played: Int
            public var wins: Int
            public var losses: Int
            public var draws: Int
            public var points: Int
            public var percentage: Double
        }

        public struct Model: Codable, Sendable {
            public var source: String
            public var correct: Int
            public var tipped: Int
        }

        public var year: Int
        public var phase: String
        public var ladder: [LadderRow]
        public var live: [Game]
        public var upcoming: [Game]
        public var recent: [Game]
        public var models: [Model]

        public var isOffSeason: Bool { phase == "offSeason" }

        /// The club card and hero, written for his club.
        public func status(for club: AFLClub, now: Date, clock: LobbyClock) -> AFLStatus {
            let row = ladder.first { $0.teamID == club.id }
            let record = row.map { "\(Cloud.ordinal($0.rank)) · \($0.wins)-\($0.losses)" + ($0.draws > 0 ? "-\($0.draws)" : "") } ?? "[ladder position]"
            let best = models.first
            let tipping = AFLStatus.Tipping(
                yourTips: "[n]/\(best?.tipped ?? 0)",
                bestModel: best.map { "\($0.correct)/\($0.tipped)" } ?? "[n]/[n]",
                yourRank: "[n] of \(models.count + 1)",
                note: isOffSeason ? "Opens with Round 1, \(year + 1)" : "Tipping arrives with the phone build"
            )

            if isOffSeason {
                let opener = upcoming.first { $0.involves(club.id) } ?? upcoming.first
                let title = opener.map { "Round 1 in \(clock.calendarDays(from: now, to: $0.start)) days" } ?? "Fixture coming"
                let sub = opener.map { "\(clock.shortDate($0.start)) · \($0.home) v \($0.away) · \($0.venue)" } ?? "Then: fixture release, then Round 1"
                return AFLStatus(
                    phaseLabel: "off-season",
                    heroKicker: opener == nil ? "Trade period and draft" : "Next season",
                    heroTitle: title,
                    heroSub: sub,
                    clubRows: [
                        .init(label: "Finished \(year)", value: record),
                        .init(label: "Next game", value: opener.map { clock.shortDate($0.start) } ?? "[fixture pending]"),
                    ],
                    clubNote: "In season this becomes next game, live score and ladder.",
                    tipping: tipping
                )
            }

            let lastGame = recent.filter { $0.involves(club.id) }.max { $0.start < $1.start }
            let lastLine: String = {
                guard let game = lastGame, let home = game.homeScore, let away = game.awayScore else { return "Bye" }
                let ours = game.homeID == club.id ? home : away
                let theirs = game.homeID == club.id ? away : home
                if ours == theirs { return "Drew with \(game.opponent(of: club.id))" }
                return ours > theirs ? "Beat \(game.opponent(of: club.id)) by \(ours - theirs)" : "Lost to \(game.opponent(of: club.id)) by \(theirs - ours)"
            }()
            let rows: [AFLStatus.Row] = [
                .init(label: "Ladder", value: record),
                .init(label: "Last game", value: lastLine),
            ]

            if let game = live.first(where: { $0.involves(club.id) }) {
                return AFLStatus(
                    phaseLabel: "live",
                    heroKicker: "\(game.roundName) · \(game.status ?? "Live") · \(game.venue)",
                    heroTitle: "\(game.home) \(game.homeScore ?? 0)  \(game.away) \(game.awayScore ?? 0)",
                    heroSub: "Live from Squiggle, refreshed every 10 minutes",
                    clubRows: rows,
                    clubNote: "Ladder updates when the siren goes.",
                    tipping: tipping
                )
            }

            if let next = upcoming.filter({ $0.involves(club.id) && $0.start > now }).min(by: { $0.start < $1.start }) {
                return AFLStatus(
                    phaseLabel: next.roundName.lowercased(),
                    heroKicker: "\(next.roundName) · \(next.venue)",
                    heroTitle: "v \(next.opponent(of: club.id)) in \(Countdown.short(from: now, to: next.start))",
                    heroSub: "\(clock.dayAndTime(next.start)) Adelaide",
                    clubRows: rows,
                    clubNote: "Live score lands here from the first bounce.",
                    tipping: tipping
                )
            }

            return AFLStatus(
                phaseLabel: "in season",
                heroKicker: "Bye",
                heroTitle: "No game this round",
                heroSub: "Next fixture shows once the AFL confirms it",
                clubRows: rows,
                clubNote: "In season this becomes next game, live score and ladder.",
                tipping: tipping
            )
        }
    }

    /// 1st, 2nd, 3rd, 4th, 11th, 12th, 13th, 21st.
    public static func ordinal(_ n: Int) -> String {
        let tens = n % 100
        if (11...13).contains(tens) { return "\(n)th" }
        switch n % 10 {
        case 1: return "\(n)st"
        case 2: return "\(n)nd"
        case 3: return "\(n)rd"
        default: return "\(n)th"
        }
    }
}
