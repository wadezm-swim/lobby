import Foundation

/// What the F1 side of the Sports room says, worked out away from the UI so it
/// can be tested. Race week and off-season read differently.
public struct F1RoomContent: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public var label: String
        public var value: String
    }

    public var phase: F1Phase
    public var heroLabel: String
    public var watermark: String
    public var countLabel: String
    public var countValue: String
    public var countSub: String
    public var teamNote: String
    /// One line per driver, like "P6 · 201 pts". Hidden while the shield is up.
    public var driverLines: [String]
    public var panelTitle: String
    public var panelRows: [Row]
    public var news: [NewsItem]
    public var hiddenHeadlines: Int
    public var shieldUp: Bool
    /// "US Grand Prix", the weekend the shield is about.
    public var shieldWeekendName: String?

    public static func make(
        snapshot: LobbySnapshot,
        team: F1Team,
        shield: SpoilerShield,
        now: Date,
        clock: LobbyClock,
        previewPhase: F1Phase? = nil
    ) -> F1RoomContent {
        let calendar = snapshot.f1Calendar
        let phase = previewPhase ?? calendar.phase(at: now)
        let shieldUp = shield.isUp(in: calendar, at: now)
        let sampleTag = snapshot.isSample ? " · sample data" : ""

        var news = phase == .offSeason && snapshot.isSample
            ? SampleData.f1OffSeasonNews(team: team, now: now)
            : snapshot.f1News
        news = NewsItem.ordered(news, favouriteTag: team.id)
        let filtered = shield.filter(news, in: calendar, at: now)

        let driverLines: [String] = team.drivers.prefix(2).map { driver in
            if shieldUp { return "Hidden until you watch" }
            guard let standing = snapshot.f1Standings.first(where: { $0.driver == driver }) else { return "P[n] · [pts] pts" }
            return "P\(standing.position) · \(formatPoints(standing.points)) pts"
        }

        let shieldName = shield.weekend(in: calendar, at: now)?.shortName

        if phase == .raceWeek, let weekend = calendar.current(at: now), let race = weekend.race {
            let underway = now >= race.start
            let rows = weekend.sessions
                .filter { $0.start.addingTimeInterval(2 * 3600) > now }
                .prefix(5)
                .map { session -> Row in
                    var label = session.kind.label
                    if let alarm = session.alarm {
                        label += alarm == session.start ? " · alarm" : " · alarm \(clock.clockWithSuffix(alarm))"
                    }
                    return Row(label: label, value: clock.dayAndTime(session.start))
                }
            return F1RoomContent(
                phase: .raceWeek,
                heroLabel: weekend.name + sampleTag,
                watermark: weekend.locality.uppercased(),
                countLabel: underway ? "Racing now" : "Lights out in",
                countValue: underway ? "Live" : Countdown.clock(from: now, to: race.start),
                countSub: "days, hours, minutes · \(clock.dayAndTime(race.start)) Adelaide",
                teamNote: "Live positions go to your lock screen from lights out.",
                driverLines: driverLines,
                panelTitle: "Sessions, Adelaide time",
                panelRows: Array(rows),
                news: filtered.visible,
                hiddenHeadlines: filtered.hidden,
                shieldUp: shieldUp,
                shieldWeekendName: shieldName
            )
        }

        let nextSeason = clock.calendar.component(.year, from: now) + (clock.calendar.component(.month, from: now) >= 7 ? 1 : 0)
        // A preview has no real next season to point at.
        let opener = previewPhase == nil ? calendar.weekends.first { ($0.race?.start ?? .distantPast) > now } : nil
        let openerLine = opener.flatMap(\.race).map { "Round 1 in \(Countdown.parts(from: now, to: $0.start).days) days" } ?? "Round 1 in [n] days"
        return F1RoomContent(
            phase: .offSeason,
            heroLabel: "Off-season" + sampleTag,
            watermark: String(nextSeason),
            countLabel: "Pre-season testing in",
            countValue: "[n] days",
            countSub: "Then car launches, then \(openerLine)",
            teamNote: "Off-season: contract news, car launch date and testing pace for your team.",
            driverLines: driverLines,
            panelTitle: "Coming up",
            panelRows: [
                Row(label: "\(team.name) car launch", value: "[date]"),
                Row(label: "Pre-season testing", value: "[dates]"),
                Row(label: "Round 1", value: opener.flatMap(\.race).map { clock.shortDate($0.start) } ?? "[date]"),
            ],
            news: filtered.visible,
            hiddenHeadlines: filtered.hidden,
            shieldUp: shieldUp,
            shieldWeekendName: shieldName
        )
    }

    static func formatPoints(_ points: Double) -> String {
        points.rounded() == points ? String(Int(points)) : String(format: "%.1f", points)
    }
}
