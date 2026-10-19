import XCTest
@testable import LobbyCore

final class ModeTests: XCTestCase {
    let hours = WorkHours.standard

    func testWorkHoursAreWeekdaysHalfEightToFive() {
        XCTAssertEqual(hours.mode(at: adelaide(2026, 10, 19, 10), clock: clock), .work)
        XCTAssertEqual(hours.mode(at: adelaide(2026, 10, 19, 8, 29), clock: clock), .offDuty)
        XCTAssertEqual(hours.mode(at: adelaide(2026, 10, 19, 17, 0), clock: clock), .offDuty)
        XCTAssertEqual(hours.mode(at: adelaide(2026, 10, 24, 10), clock: clock), .offDuty) // Saturday
    }

    func testNextChangeSkipsTheWeekend() {
        XCTAssertEqual(hours.nextChange(after: adelaide(2026, 10, 19, 10), clock: clock), adelaide(2026, 10, 19, 17))
        XCTAssertEqual(hours.nextChange(after: adelaide(2026, 10, 23, 18), clock: clock), adelaide(2026, 10, 26, 8, 30))
    }

    func testToggleOverridesUntilTheNextNaturalChange() {
        var state = ModeState()
        let morning = adelaide(2026, 10, 19, 10)
        state.choose(.offDuty, at: morning, hours: hours, clock: clock)
        XCTAssertEqual(state.mode(at: morning, hours: hours, clock: clock), .offDuty)
        XCTAssertEqual(state.mode(at: adelaide(2026, 10, 19, 16, 59), hours: hours, clock: clock), .offDuty)
        // After 5pm the override has run out and the natural mode is off duty anyway;
        // next morning it's back to work.
        XCTAssertEqual(state.mode(at: adelaide(2026, 10, 20, 9), hours: hours, clock: clock), .work)
    }

    func testChoosingTheNaturalModeClearsTheOverride() {
        var state = ModeState(override: .offDuty, overrideUntil: adelaide(2026, 10, 19, 17))
        state.choose(.work, at: adelaide(2026, 10, 19, 10), hours: hours, clock: clock)
        XCTAssertNil(state.override)
        XCTAssertNil(state.overrideUntil)
    }

    func testGreeting() {
        XCTAssertEqual(Greeting.text(at: adelaide(2026, 10, 19, 9), name: "Wade", clock: clock), "Good morning, Wade")
        XCTAssertEqual(Greeting.text(at: adelaide(2026, 10, 19, 14), name: "Wade", clock: clock), "Good afternoon, Wade")
        XCTAssertEqual(Greeting.text(at: adelaide(2026, 10, 19, 18, 40), name: "Wade", clock: clock), "Evening, Wade")
    }

    func testNextUpIsTheMeetingOnNowOrNext() {
        let meetings = SampleData.meetings(on: adelaide(2026, 10, 19), clock: clock, tag: "x")
        XCTAssertEqual(Meeting.nextUp(in: meetings, at: adelaide(2026, 10, 19, 9, 50))?.title, "Ops catch-up")
        XCTAssertEqual(Meeting.nextUp(in: meetings, at: adelaide(2026, 10, 19, 12, 30))?.title, "Focus block")
        XCTAssertNil(Meeting.nextUp(in: meetings, at: adelaide(2026, 10, 19, 17)))
    }

    func testWeeklyLogIsReadyFridayAtThree() {
        XCTAssertEqual(WeeklyLog.nextReady(after: handoverMorning, clock: clock), adelaide(2026, 10, 23, 15))
        XCTAssertEqual(WeeklyLog.nextReady(after: adelaide(2026, 10, 23, 16), clock: clock), adelaide(2026, 10, 30, 15))
        XCTAssertFalse(WeeklyLog.isReady(at: adelaide(2026, 10, 23, 14, 59), clock: clock))
        XCTAssertTrue(WeeklyLog.isReady(at: adelaide(2026, 10, 23, 15), clock: clock))
        XCTAssertTrue(WeeklyLog.isReady(at: adelaide(2026, 10, 25, 10), clock: clock))
        XCTAssertFalse(WeeklyLog.isReady(at: handoverMorning, clock: clock))
    }

    func testWaitingOnGoesStaleAfterFourDays() {
        let item = WaitingOn(id: "w", initials: "SA", what: "Lane booking", since: adelaide(2026, 10, 15, 9), tint: .sky)
        XCTAssertTrue(item.isStale(at: handoverMorning, clock: clock))
        let fresh = WaitingOn(id: "w", initials: "OF", what: "Roster", since: adelaide(2026, 10, 17, 9), tint: .peach)
        XCTAssertFalse(fresh.isStale(at: handoverMorning, clock: clock))
    }
}
