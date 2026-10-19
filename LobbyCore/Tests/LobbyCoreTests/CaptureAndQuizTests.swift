import XCTest
@testable import LobbyCore

final class CaptureAndQuizTests: XCTestCase {
    func testParsesTheConciergeExample() {
        let parsed = CaptureParser.parse("chase officials roster thursday", now: handoverMorning, clock: clock)
        XCTAssertEqual(parsed.title, "Chase officials roster")
        XCTAssertEqual(parsed.due, adelaide(2026, 10, 22))
        XCTAssertEqual(parsed.searchTerm, "officials roster")
    }

    func testParsesOtherDayWords() {
        XCTAssertEqual(CaptureParser.parse("call Jane tomorrow", now: handoverMorning, clock: clock).due, adelaide(2026, 10, 20))
        let byFriday = CaptureParser.parse("book flights by Friday", now: handoverMorning, clock: clock)
        XCTAssertEqual(byFriday.title, "Book flights")
        XCTAssertEqual(byFriday.due, adelaide(2026, 10, 23))
        let nextWeek = CaptureParser.parse("lane booking next week", now: handoverMorning, clock: clock)
        XCTAssertEqual(nextWeek.title, "Lane booking")
        XCTAssertEqual(nextWeek.due, adelaide(2026, 10, 26))
        XCTAssertEqual(CaptureParser.parse("send invoice monday", now: handoverMorning, clock: clock).due, adelaide(2026, 10, 19), "same weekday means today")
        XCTAssertEqual(CaptureParser.parse("follow up the roster", now: handoverMorning, clock: clock).searchTerm, "the roster")
    }

    func testLeavesUndatedCapturesAlone() {
        let parsed = CaptureParser.parse("pool party for Wave Makers", now: handoverMorning, clock: clock)
        XCTAssertNil(parsed.due)
        XCTAssertEqual(parsed.title, "Pool party for Wave Makers")
        XCTAssertEqual(parsed.searchTerm, "pool party for wave makers")
    }

    func testMatchesACaptureToItsProject() {
        let projects = SampleData.snapshot(now: handoverMorning).projects
        XCTAssertEqual(ProjectMatcher.match("chase officials roster thursday", in: projects)?.name, "State SC Champs 2026")
        XCTAssertEqual(ProjectMatcher.match("judges sheet for COTY", in: projects)?.name, "Club of the Year 2026")
        XCTAssertNil(ProjectMatcher.match("buy milk", in: projects))
    }

    func testDailyThreeIsOnePerTopicAndStableForTheDay() {
        let today = QuizBank.starter.daily(for: "2026-10-19")
        XCTAssertEqual(today.map(\.topic), [.aviation, .f1, .port])
        XCTAssertEqual(today, QuizBank.starter.daily(for: "2026-10-19"))
        for question in QuizBank.starter.questions {
            XCTAssertTrue(question.options.contains(question.answer), question.id)
        }
        let week = (19...25).map { QuizBank.starter.daily(for: "2026-10-\($0)").map(\.id) }
        XCTAssertGreaterThan(Set(week).count, 1, "questions change across the week")
    }

    func testStreakCountsCleanDaysAndResetsTomorrowAfterAMiss() {
        var log = QuizLog()
        for day in 16...18 {
            for _ in 0..<3 { log.record(correct: true, on: "2026-10-\(day)") }
        }
        XCTAssertEqual(log.streak(at: handoverMorning, clock: clock), 3, "today not started yet")
        log.record(correct: true, on: "2026-10-19")
        XCTAssertEqual(log.streak(at: handoverMorning, clock: clock), 4)
        log.record(correct: false, on: "2026-10-19")
        XCTAssertEqual(log.streak(at: handoverMorning, clock: clock), 3, "a miss today keeps yesterday's run for now")
        XCTAssertEqual(log.streak(at: adelaide(2026, 10, 20, 9), clock: clock), 0, "and it resets tomorrow")
    }

    func testPruneKeepsTwoMonths() {
        var log = QuizLog(days: ["2026-01-01": [true], "2026-10-18": [true]])
        log.prune(keepingDaysFrom: handoverMorning, clock: clock)
        XCTAssertEqual(Array(log.days.keys), ["2026-10-18"])
    }

    func testLookingForwardPrefersABigThingWithinFourMonths() {
        let snapshot = SampleData.snapshot(now: handoverMorning)
        let trip = snapshot.trips[0]
        let things = [
            LookingForward.Thing(title: "US Grand Prix", date: adelaide(2026, 10, 26, 5, 30), isMajor: false),
            LookingForward.Thing(title: trip.name, date: trip.departs, isMajor: true),
        ]
        let pick = LookingForward.pick(things, at: handoverMorning)
        XCTAssertEqual(pick?.title, "Sri Lanka")
        XCTAssertEqual(LookingForward.phrase(pick!, at: handoverMorning, clock: clock), "Sri Lanka in 47 days")

        let farTrip = LookingForward.Thing(title: "Japan", date: adelaide(2027, 6, 1), isMajor: true)
        XCTAssertEqual(LookingForward.pick([things[0], farTrip], at: handoverMorning)?.title, "US Grand Prix")
        XCTAssertEqual(LookingForward.phrase(LookingForward.Thing(title: "Race", date: adelaide(2026, 10, 20, 6), isMajor: false), at: handoverMorning, clock: clock), "Race tomorrow")
    }

    func testSampleSnapshotIsUsableAtAnyHour() {
        // A Saturday night still has a next workday, a next race and a next trip.
        let saturdayNight = adelaide(2026, 10, 24, 22)
        let snapshot = SampleData.snapshot(now: saturdayNight)
        XCTAssertNotNil(Meeting.nextUp(in: snapshot.meetings, at: saturdayNight))
        XCTAssertNotNil(snapshot.f1Calendar.current(at: saturdayNight))
        XCTAssertNotNil(snapshot.nextTrip(after: saturdayNight))
        XCTAssertEqual(snapshot.meetings(on: adelaide(2026, 10, 26), clock: clock).count, 4)
    }
}
