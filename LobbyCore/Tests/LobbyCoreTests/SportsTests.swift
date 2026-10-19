import XCTest
@testable import LobbyCore

final class SportsTests: XCTestCase {
    let weekend = F1Weekend(id: "2026-18", name: "United States Grand Prix", shortName: "US Grand Prix", locality: "Austin", sessions: [
        F1Session(kind: .practice1, start: adelaide(2026, 10, 24, 4)),
        F1Session(kind: .qualifying, start: adelaide(2026, 10, 25, 7, 30)),
        F1Session(kind: .race, start: adelaide(2026, 10, 26, 6, 30)),
    ])

    var calendar: F1Calendar { F1Calendar(weekends: [weekend]) }

    func testShieldGoesUpWhenQualifyingStarts() {
        let shield = SpoilerShield()
        XCTAssertFalse(shield.isUp(in: calendar, at: adelaide(2026, 10, 24, 5)), "practice is not a spoiler")
        XCTAssertTrue(shield.isUp(in: calendar, at: adelaide(2026, 10, 25, 7, 31)))
    }

    func testWatchingQualifyingDoesNotCoverTheRace() {
        var shield = SpoilerShield()
        shield.markWatched(weekend, at: adelaide(2026, 10, 25, 10))
        XCTAssertFalse(shield.isUp(in: calendar, at: adelaide(2026, 10, 25, 12)))
        XCTAssertTrue(shield.isUp(in: calendar, at: adelaide(2026, 10, 26, 7)), "race start puts it back up")
        shield.markWatched(weekend, at: adelaide(2026, 10, 26, 20))
        XCTAssertFalse(shield.isUp(in: calendar, at: adelaide(2026, 10, 27, 9)))
        shield.hideAgain(weekend)
        XCTAssertTrue(shield.isUp(in: calendar, at: adelaide(2026, 10, 27, 9)))
    }

    func testShieldHoldsBackResultHeadlinesOnly() {
        let news = [
            NewsItem(id: "1", source: "F1", title: "Team news", published: handoverMorning),
            NewsItem(id: "2", source: "F1", title: "[result]", published: handoverMorning, mayContainResult: true),
        ]
        let up = SpoilerShield().filter(news, in: calendar, at: adelaide(2026, 10, 26, 8))
        XCTAssertEqual(up.visible.map(\.id), ["1"])
        XCTAssertEqual(up.hidden, 1)
        let down = SpoilerShield().filter(news, in: calendar, at: adelaide(2026, 10, 24, 8))
        XCTAssertEqual(down.visible.count, 2)
        XCTAssertEqual(down.hidden, 0)
    }

    func testQualifyingPicksScoring() {
        let picks = QualifyingPicks(weekendID: weekend.id, picks: ["Norris", "Leclerc", "Piastri"])
        XCTAssertEqual(picks.score(against: ["Norris", "Piastri", "Russell"]), 3) // Norris exact, Piastri wrong slot
        XCTAssertEqual(picks.score(against: ["Norris", "Leclerc", "Piastri"]), 6)
        XCTAssertEqual(picks.score(against: ["Russell", "Antonelli", "Hamilton"]), 0)
        XCTAssertEqual(QualifyingPicks(weekendID: "x").score(against: ["Norris", "Piastri", "Russell"]), 0)
        XCTAssertFalse(QualifyingPicks.isLocked(weekend, at: adelaide(2026, 10, 25, 7, 29)))
        XCTAssertTrue(QualifyingPicks.isLocked(weekend, at: adelaide(2026, 10, 25, 7, 30)))
    }

    func testPhaseIsOffSeasonAfterTheLastRace() {
        XCTAssertEqual(calendar.phase(at: handoverMorning), .raceWeek)
        XCTAssertEqual(calendar.current(at: handoverMorning)?.id, "2026-18")
        XCTAssertEqual(calendar.phase(at: adelaide(2026, 12, 20)), .offSeason)
    }

    func testTeamsAndClubs() {
        XCTAssertEqual(F1Team.all.count, 11)
        XCTAssertEqual(Set(F1Team.all.map(\.id)).count, 11)
        XCTAssertEqual(F1Team.mclaren.colorHex, "#FF8000")
        XCTAssertEqual(AFLClub.all.count, 18)
        XCTAssertEqual(Set(AFLClub.all.map(\.id)), Set(1...18))
        XCTAssertEqual(AFLClub.all.first, .portAdelaide)
        XCTAssertEqual(AFLClub.portAdelaide.id, 13, "Squiggle's id for Port")
    }

    func testNewsPutsHisTeamFirst() {
        let items = [
            NewsItem(id: "new", source: "F1", title: "Newest", published: adelaide(2026, 10, 19, 9)),
            NewsItem(id: "team", source: "McLaren", title: "Team", published: adelaide(2026, 10, 18, 9), tags: ["mclaren"]),
            NewsItem(id: "old", source: "F1", title: "Old", published: adelaide(2026, 10, 17, 9)),
        ]
        XCTAssertEqual(NewsItem.ordered(items, favouriteTag: "mclaren").map(\.id), ["team", "new", "old"])
    }

    func testRaceWeekRoomMatchesTheMockUp() {
        let snapshot = SampleData.snapshot(now: handoverMorning)
        let content = F1RoomContent.make(snapshot: snapshot, team: .mclaren, shield: SpoilerShield(), now: handoverMorning, clock: clock)
        XCTAssertEqual(content.phase, .raceWeek)
        XCTAssertEqual(content.heroLabel, "United States Grand Prix · sample data")
        XCTAssertEqual(content.watermark, "AUSTIN")
        XCTAssertEqual(content.countLabel, "Lights out in")
        XCTAssertEqual(content.countValue, "6:19:40")
        XCTAssertEqual(content.countSub, "days, hours, minutes · Mon 5:30am Adelaide")
        XCTAssertEqual(content.panelRows.map(\.label), ["Practice 1", "Qualifying · alarm", "Race · alarm 5:15am"])
        XCTAssertEqual(content.panelRows.map(\.value), ["Sat 4:00am", "Sun 7:30am", "Mon 5:30am"])
        XCTAssertTrue(content.shieldUp, "the sample's last GP is unwatched")
        XCTAssertEqual(content.shieldWeekendName, "[Last GP]")
        XCTAssertEqual(content.hiddenHeadlines, 3)
        XCTAssertEqual(content.news.first?.source, "McLaren · team news")
        XCTAssertEqual(content.driverLines, ["Hidden until you watch", "Hidden until you watch"])
    }

    func testOffSeasonPreview() {
        let snapshot = SampleData.snapshot(now: handoverMorning, f1TeamID: "ferrari")
        let content = F1RoomContent.make(snapshot: snapshot, team: F1Team.team(id: "ferrari")!, shield: SpoilerShield(), now: handoverMorning, clock: clock, previewPhase: .offSeason)
        XCTAssertEqual(content.watermark, "2027")
        XCTAssertEqual(content.panelTitle, "Coming up")
        XCTAssertEqual(content.panelRows.first?.label, "Ferrari car launch")
        XCTAssertEqual(content.countSub, "Then car launches, then Round 1 in [n] days")
    }

    func testStandingsShowOnceTheShieldIsDown() {
        var snapshot = SampleData.snapshot(now: handoverMorning)
        snapshot.f1Standings = [
            DriverStanding(position: 6, driver: "Norris", teamID: "mclaren", points: 201),
            DriverStanding(position: 7, driver: "Piastri", teamID: "mclaren", points: 138.5),
        ]
        var shield = SpoilerShield()
        let last = shield.weekend(in: snapshot.f1Calendar, at: handoverMorning)!
        shield.markWatched(last, at: handoverMorning)
        let content = F1RoomContent.make(snapshot: snapshot, team: .mclaren, shield: shield, now: handoverMorning, clock: clock)
        XCTAssertFalse(content.shieldUp)
        XCTAssertEqual(content.hiddenHeadlines, 0)
        XCTAssertEqual(content.driverLines, ["P6 · 201 pts", "P7 · 138.5 pts"])
    }
}
