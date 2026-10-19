import Foundation

/// Where the AFL season is at, written as the club card and hero show it.
public struct AFLStatus: Codable, Hashable, Sendable {
    public var phaseLabel: String
    public var heroKicker: String
    public var heroTitle: String
    public var heroSub: String
    public var clubRows: [Row]
    public var clubNote: String
    public var tipping: Tipping

    public struct Row: Codable, Hashable, Sendable {
        public var label: String
        public var value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    /// "Beat the models": his tips against Squiggle's computer tipsters.
    public struct Tipping: Codable, Hashable, Sendable {
        public var yourTips: String
        public var bestModel: String
        public var yourRank: String
        public var note: String

        public init(yourTips: String, bestModel: String, yourRank: String, note: String) {
            self.yourTips = yourTips
            self.bestModel = bestModel
            self.yourRank = yourRank
            self.note = note
        }
    }

    public init(phaseLabel: String, heroKicker: String, heroTitle: String, heroSub: String, clubRows: [Row], clubNote: String, tipping: Tipping) {
        self.phaseLabel = phaseLabel
        self.heroKicker = heroKicker
        self.heroTitle = heroTitle
        self.heroSub = heroSub
        self.clubRows = clubRows
        self.clubNote = clubNote
        self.tipping = tipping
    }
}

/// Everything Lobby shows, in one place. Sample data now; each part switches to
/// real data one at a time.
public struct LobbySnapshot: Sendable {
    public var isSample: Bool
    public var ownerName: String

    // Work
    public var meetings: [Meeting]
    public var topThree: [TaskItem]
    /// Candidates for "Swap one".
    public var topThreeBacklog: [TaskItem]
    public var waitingOn: [WaitingOn]
    public var projects: [Project]

    // Life
    public var trips: [Trip]
    public var body: BodySummary
    public var fleet: FleetSummary
    public var nowPlaying: NowPlaying?
    public var quizBank: QuizBank

    // Sports
    public var f1Calendar: F1Calendar
    /// Empty until live standings arrive.
    public var f1Standings: [DriverStanding]
    /// Top three surnames from the latest result, nil until live data arrives.
    public var f1LatestTopThree: [String]?
    public var f1News: [NewsItem]
    public var aflStatus: AFLStatus
    public var aflNews: [NewsItem]

    public init(isSample: Bool, ownerName: String, meetings: [Meeting], topThree: [TaskItem], topThreeBacklog: [TaskItem], waitingOn: [WaitingOn], projects: [Project], trips: [Trip], body: BodySummary, fleet: FleetSummary, nowPlaying: NowPlaying?, quizBank: QuizBank, f1Calendar: F1Calendar, f1Standings: [DriverStanding], f1LatestTopThree: [String]?, f1News: [NewsItem], aflStatus: AFLStatus, aflNews: [NewsItem]) {
        self.isSample = isSample
        self.ownerName = ownerName
        self.meetings = meetings
        self.topThree = topThree
        self.topThreeBacklog = topThreeBacklog
        self.waitingOn = waitingOn
        self.projects = projects
        self.trips = trips
        self.body = body
        self.fleet = fleet
        self.nowPlaying = nowPlaying
        self.quizBank = quizBank
        self.f1Calendar = f1Calendar
        self.f1Standings = f1Standings
        self.f1LatestTopThree = f1LatestTopThree
        self.f1News = f1News
        self.aflStatus = aflStatus
        self.aflNews = aflNews
    }

    public func meetings(on day: Date, clock: LobbyClock) -> [Meeting] {
        meetings
            .filter { clock.startOfDay($0.start) == clock.startOfDay(day) }
            .sorted { $0.start < $1.start }
    }

    public func nextTrip(after now: Date) -> Trip? {
        trips.filter { $0.departs > now }.min { $0.departs < $1.departs }
    }
}

/// "Looking forward to": the nearest good thing coming up. Trips and other big
/// things win if one is within four months; otherwise the nearest of anything.
public enum LookingForward {
    public struct Thing: Equatable, Sendable {
        public var title: String
        public var date: Date
        public var isMajor: Bool

        public init(title: String, date: Date, isMajor: Bool) {
            self.title = title
            self.date = date
            self.isMajor = isMajor
        }
    }

    public static func pick(_ things: [Thing], at now: Date) -> Thing? {
        let ahead = things.filter { $0.date > now }.sorted { $0.date < $1.date }
        let horizon = now.addingTimeInterval(120 * 86400)
        return ahead.first { $0.isMajor && $0.date <= horizon } ?? ahead.first
    }

    /// "Sri Lanka in 47 days", "Sri Lanka tomorrow".
    public static func phrase(_ thing: Thing, at now: Date, clock: LobbyClock) -> String {
        switch clock.calendarDays(from: now, to: thing.date) {
        case ...0: return "\(thing.title) today"
        case 1: return "\(thing.title) tomorrow"
        case let days: return "\(thing.title) in \(days) days"
        }
    }
}
