import Foundation

/// The mock-ups' sample data, with times built around `now` so countdowns tick
/// and "next up" moves through the day. Anything that would be a real-world
/// fact (results, ladder, headlines) stays as a [bracketed] placeholder.
public enum SampleData {
    public static func snapshot(now: Date, clock: LobbyClock = .adelaide, f1TeamID: String = F1Team.mclaren.id) -> LobbySnapshot {
        let team = F1Team.team(id: f1TeamID) ?? .mclaren
        let workday = clock.isWeekend(now) ? clock.next(weekday: 2, after: now) : clock.startOfDay(now)
        let nextWorkday: Date = {
            var day = clock.addingDays(1, to: workday)
            while clock.isWeekend(day) { day = clock.addingDays(1, to: day) }
            return day
        }()

        return LobbySnapshot(
            isSample: true,
            ownerName: "Wade",
            meetings: meetings(on: workday, clock: clock, tag: "a") + meetings(on: nextWorkday, clock: clock, tag: "b"),
            topThree: [
                TaskItem(id: "t1", title: "COTY judges' sheet"),
                TaskItem(id: "t2", title: "Olly Timing install quote"),
                TaskItem(id: "t3", title: "Wave Makers dates", done: true),
            ],
            topThreeBacklog: [
                TaskItem(id: "t4", title: "Officials roster for State SC Champs"),
                TaskItem(id: "t5", title: "Training invites for Wave Makers"),
                TaskItem(id: "t6", title: "Follow up the Nov meet lane booking"),
            ],
            waitingOn: [
                WaitingOn(id: "w1", initials: "SA", what: "Lane booking, Nov meet", since: clock.addingDays(-4, to: now), tint: .sky),
                WaitingOn(id: "w2", initials: "OF", what: "Officials roster", since: clock.addingDays(-2, to: now), tint: .peach),
            ],
            projects: [
                Project(id: "p1", name: "Olly Timing rollout", nextStep: "Walkthrough today"),
                Project(id: "p2", name: "Club of the Year 2026", nextStep: "Judges' sheet"),
                Project(id: "p3", name: "Wave Makers", nextStep: "Training invites"),
                Project(id: "p4", name: "State SC Champs 2026", nextStep: "Officials roster"),
            ],
            trips: [
                Trip(id: "trip1", name: "Sri Lanka", flight: "UL609 MEL → CMB",
                     departs: clock.date(on: clock.addingDays(47, to: now), hour: 21, minute: 40)),
            ],
            body: BodySummary(
                chips: [
                    .init(text: "Well rested", highlighted: true),
                    .init(text: "2:19 /100m"),
                    .init(text: "Wk 9 of 14"),
                ],
                tomorrow: "ShredX upper 6:30am, swim, sauna"
            ),
            fleet: FleetSummary(flown: 4, spotted: 9, total: 20, latest: "VH-ZNC spotted at ADL"),
            nowPlaying: NowPlaying(title: "[Track or podcast]", source: "Spotify", isPlaying: true),
            quizBank: .starter,
            f1Calendar: f1Calendar(now: now, clock: clock),
            f1Standings: [],
            f1LatestTopThree: nil,
            f1News: f1News(team: team, now: now),
            aflStatus: aflOffSeason,
            aflNews: [
                NewsItem(id: "a1", source: "Port Adelaide FC", title: "[Latest club headline]", published: now, tags: ["13"]),
                NewsItem(id: "a2", source: "AFL.com.au · trades", title: "[Latest trade headline]", published: now.addingTimeInterval(-3600), tags: ["13"]),
                NewsItem(id: "a3", source: "Draft watch", title: "[Latest draft headline]", published: now.addingTimeInterval(-7200)),
            ]
        )
    }

    static func meetings(on day: Date, clock: LobbyClock, tag: String) -> [Meeting] {
        [
            Meeting(id: "m1\(tag)", title: "Ops catch-up", start: clock.date(on: day, hour: 10, minute: 30), minutes: 30, location: "Boardroom"),
            Meeting(id: "m2\(tag)", title: "Focus block", start: clock.date(on: day, hour: 12), minutes: 90, note: "Held by Lobby for the COTY sheet"),
            Meeting(id: "m3\(tag)", title: "Olly Timing install walkthrough", start: clock.date(on: day, hour: 13, minute: 30), minutes: 60, location: "SAALC"),
            Meeting(id: "m4\(tag)", title: "Competitions Committee prep", start: clock.date(on: day, hour: 15, minute: 30), minutes: 45, location: "Online"),
        ]
    }

    /// A finished weekend (so the shield has something to hide) and the next one,
    /// with the mock-up's Adelaide times: Sat 4:00am, Sun 7:30am, Mon 5:30am.
    static func f1Calendar(now: Date, clock: LobbyClock) -> F1Calendar {
        let raceDay = clock.next(weekday: 2, after: clock.addingDays(2, to: now))
        func weekend(id: String, name: String, short: String, locality: String, raceDay: Date) -> F1Weekend {
            let fp1 = clock.date(on: clock.addingDays(-2, to: raceDay), hour: 4)
            let quali = clock.date(on: clock.addingDays(-1, to: raceDay), hour: 7, minute: 30)
            let race = clock.date(on: raceDay, hour: 5, minute: 30)
            return F1Weekend(id: id, name: name, shortName: short, locality: locality, sessions: [
                F1Session(kind: .practice1, start: fp1),
                F1Session(kind: .qualifying, start: quali, alarm: quali),
                F1Session(kind: .race, start: race, alarm: race.addingTimeInterval(-15 * 60)),
            ])
        }
        return F1Calendar(weekends: [
            weekend(id: "sample-last", name: "[Last Grand Prix]", short: "[Last GP]", locality: "[Last GP]", raceDay: clock.addingDays(-14, to: raceDay)),
            weekend(id: "sample-next", name: "United States Grand Prix", short: "US Grand Prix", locality: "Austin", raceDay: raceDay),
        ])
    }

    static func f1News(team: F1Team, now: Date) -> [NewsItem] {
        [
            NewsItem(id: "n1", source: "\(team.name) · team news", title: "[Latest team headline]", published: now, tags: [team.id]),
            NewsItem(id: "n2", source: "Formula1.com", title: "[Latest headline]", published: now.addingTimeInterval(-1800)),
            NewsItem(id: "n3", source: "FIA · stewards decisions", title: "[Latest decision]", published: now.addingTimeInterval(-3600)),
            NewsItem(id: "n4", source: "Your Armchair Guide", title: "US GP guide is ready in Notion", published: now.addingTimeInterval(-5400)),
            NewsItem(id: "n5", source: "Formula1.com", title: "[Result headline]", published: now.addingTimeInterval(-7200), mayContainResult: true),
            NewsItem(id: "n6", source: "The Race", title: "[Result headline]", published: now.addingTimeInterval(-9000), mayContainResult: true),
            NewsItem(id: "n7", source: "RaceFans", title: "[Result headline]", published: now.addingTimeInterval(-10800), mayContainResult: true),
        ]
    }

    /// The mock-up's off-season F1 headlines, shown when previewing the off-season.
    public static func f1OffSeasonNews(team: F1Team, now: Date) -> [NewsItem] {
        [
            NewsItem(id: "o1", source: "Driver market", title: "[Latest contract headline]", published: now),
            NewsItem(id: "o2", source: "\(team.name) · team news", title: "[Latest team headline]", published: now.addingTimeInterval(-1800), tags: [team.id]),
            NewsItem(id: "o3", source: "Regulations", title: "[Latest technical headline]", published: now.addingTimeInterval(-3600)),
            NewsItem(id: "o4", source: "Season review", title: "Your 2026 in numbers", published: now.addingTimeInterval(-5400)),
        ]
    }

    static let aflOffSeason = AFLStatus(
        phaseLabel: "off-season",
        heroKicker: "Trade period and draft",
        heroTitle: "Draft in [n] days",
        heroSub: "Then: fixture release [date] · Round 1 [date]",
        clubRows: [
            .init(label: "Finished 2026", value: "[ladder position]"),
            .init(label: "Ins and outs", value: "[from trade news]"),
        ],
        clubNote: "In season this becomes next game, live score and ladder.",
        tipping: .init(yourTips: "[n]/[n]", bestModel: "[n]/[n]", yourRank: "[n] of [n]", note: "Opens with Round 1, 2027 · sample")
    )
}
