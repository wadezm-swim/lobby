import Foundation

/// Hides results, standings and result headlines everywhere in Lobby until he
/// taps "I've watched it".
///
/// The shield goes up when a session with a result starts (sprint qualifying,
/// sprint, qualifying, race) and stays up until he says he's watched it. Tapping
/// after qualifying doesn't cover the race: when the race starts the shield goes
/// back up.
public struct SpoilerShield: Codable, Equatable, Sendable {
    /// Weekend id to when he tapped "I've watched it".
    public var watchedAt: [String: Date]

    public init(watchedAt: [String: Date] = [:]) {
        self.watchedAt = watchedAt
    }

    /// The weekend the shield is about right now, whether it's up or down.
    public func weekend(in calendar: F1Calendar, at now: Date) -> F1Weekend? {
        calendar.latestWithResult(at: now)
    }

    public func isUp(in calendar: F1Calendar, at now: Date) -> Bool {
        guard let weekend = weekend(in: calendar, at: now),
              let session = weekend.latestResultSession(at: now) else { return false }
        if let tapped = watchedAt[weekend.id], tapped >= session.start { return false }
        return true
    }

    public mutating func markWatched(_ weekend: F1Weekend, at now: Date) {
        watchedAt[weekend.id] = now
    }

    public mutating func hideAgain(_ weekend: F1Weekend) {
        watchedAt[weekend.id] = nil
    }

    /// Headlines safe to show, and how many were held back.
    public func filter(_ news: [NewsItem], in calendar: F1Calendar, at now: Date) -> (visible: [NewsItem], hidden: Int) {
        guard isUp(in: calendar, at: now) else { return (news, 0) }
        let visible = news.filter { !$0.mayContainResult }
        return (visible, news.count - visible.count)
    }
}

/// F1 qualifying top-three predictions. Picks lock when Q1 starts and are scored
/// once the shield comes down.
public struct QualifyingPicks: Codable, Equatable, Sendable {
    public var weekendID: String
    /// Driver surnames for P1, P2, P3. Empty string means not picked yet.
    public var picks: [String]

    public init(weekendID: String, picks: [String] = ["", "", ""]) {
        self.weekendID = weekendID
        self.picks = picks
    }

    public static func isLocked(_ weekend: F1Weekend, at now: Date) -> Bool {
        guard let quali = weekend.qualifying else { return true }
        return now >= quali.start
    }

    /// Two points for the right driver in the right slot, one for a driver who
    /// made the top three in a different slot.
    public func score(against topThree: [String]) -> Int {
        var total = 0
        for (slot, pick) in picks.enumerated() where !pick.isEmpty {
            if slot < topThree.count && topThree[slot] == pick {
                total += 2
            } else if topThree.contains(pick) {
                total += 1
            }
        }
        return total
    }
}
