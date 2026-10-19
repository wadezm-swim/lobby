import XCTest
@testable import LobbyCore

final class ClockTests: XCTestCase {
    func testFormatsTimesTheWayTheDesignsDo() {
        XCTAssertEqual(clock.clock(adelaide(2026, 10, 19, 10, 30)), "10:30")
        XCTAssertEqual(clock.clock(adelaide(2026, 10, 19, 13, 30)), "1:30")
        XCTAssertEqual(clock.clock(adelaide(2026, 10, 19, 0, 5)), "12:05")
        XCTAssertEqual(clock.clockWithSuffix(adelaide(2026, 10, 24, 4, 0)), "4:00am")
        XCTAssertEqual(clock.clockWithSuffix(adelaide(2026, 10, 24, 12, 0)), "12:00pm")
        XCTAssertEqual(clock.dayAndTime(adelaide(2026, 10, 24, 4, 0)), "Sat 4:00am")
        XCTAssertEqual(clock.shortDate(adelaide(2026, 10, 22)), "Thu 22 Oct")
        XCTAssertEqual(clock.longDate(adelaide(2026, 10, 19)), "Monday 19 October")
        XCTAssertEqual(clock.dayKey(adelaide(2026, 10, 19, 23, 59)), "2026-10-19")
    }

    func testConvertsJolpicaUTCToAdelaideDaylightTime() {
        // The 2026 US GP is listed as 2026-10-25 20:00 UTC. Adelaide is on
        // daylight time (UTC+10:30) from the first Sunday in October.
        XCTAssertEqual(clock.dayAndTime(utc("2026-10-25T20:00:00Z")), "Mon 6:30am")
        // Before daylight saving it's UTC+9:30.
        XCTAssertEqual(clock.dayAndTime(utc("2026-06-14T13:00:00Z")), "Sun 10:30pm")
    }

    func testCountsCalendarDaysAcrossDaylightSaving() {
        XCTAssertEqual(clock.calendarDays(from: adelaide(2026, 10, 3, 23), to: adelaide(2026, 10, 5, 1)), 2)
        XCTAssertEqual(clock.calendarDays(from: adelaide(2026, 10, 19, 23), to: adelaide(2026, 10, 20, 0, 30)), 1)
    }

    func testFindsTheNextWeekday() {
        // From Monday 19 Oct: next Thursday is the 22nd, next Monday the 26th.
        XCTAssertEqual(clock.next(weekday: 5, after: handoverMorning), adelaide(2026, 10, 22))
        XCTAssertEqual(clock.next(weekday: 2, after: handoverMorning), adelaide(2026, 10, 26))
        XCTAssertEqual(clock.next(weekday: 2, after: handoverMorning, includingToday: true), adelaide(2026, 10, 19))
    }

    func testCountdowns() {
        let from = adelaide(2026, 10, 19, 9, 50)
        XCTAssertEqual(Countdown.short(from: from, to: adelaide(2026, 10, 24, 4, 0)), "4d 18h")
        XCTAssertEqual(Countdown.short(from: from, to: adelaide(2026, 10, 19, 15, 10)), "5h 20m")
        XCTAssertEqual(Countdown.short(from: from, to: adelaide(2026, 10, 19, 10, 30)), "40 min")
        XCTAssertEqual(Countdown.relative(from: from, to: adelaide(2026, 10, 19, 10, 30)), "in 40 min")
        XCTAssertEqual(Countdown.relative(from: from, to: adelaide(2026, 10, 19, 9, 0)), "now")
        XCTAssertEqual(Countdown.clock(from: from, to: adelaide(2026, 10, 26, 5, 30)), "6:19:40")
        XCTAssertEqual(Countdown.duration(minutes: 30), "30 min")
        XCTAssertEqual(Countdown.duration(minutes: 60), "1 hr")
        XCTAssertEqual(Countdown.duration(minutes: 90), "1 hr 30 min")
    }

    func testSunriseAndSunsetInAdelaide() throws {
        // Mid October in Adelaide: sunrise about 6:35am, sunset about 7:35pm (daylight time).
        let october = try XCTUnwrap(Sun.adelaide.times(on: adelaide(2026, 10, 19, 12)))
        XCTAssertEqual(october.sunrise.timeIntervalSince(adelaide(2026, 10, 19, 6, 35)), 0, accuracy: 12 * 60)
        XCTAssertEqual(october.sunset.timeIntervalSince(adelaide(2026, 10, 19, 19, 35)), 0, accuracy: 12 * 60)

        // Midwinter: sunrise about 7:20am, sunset about 5:15pm (standard time).
        let june = try XCTUnwrap(Sun.adelaide.times(on: adelaide(2026, 6, 21, 12)))
        XCTAssertEqual(june.sunrise.timeIntervalSince(adelaide(2026, 6, 21, 7, 20)), 0, accuracy: 12 * 60)
        XCTAssertEqual(june.sunset.timeIntervalSince(adelaide(2026, 6, 21, 17, 15)), 0, accuracy: 12 * 60)

        XCTAssertTrue(Sun.adelaide.isNight(at: adelaide(2026, 10, 19, 22)))
        XCTAssertTrue(Sun.adelaide.isNight(at: adelaide(2026, 10, 19, 5)))
        XCTAssertFalse(Sun.adelaide.isNight(at: adelaide(2026, 10, 19, 12)))
    }

    func testPolarDaysHaveNoSunrise() {
        let svalbard = Sun(latitude: 78.2, longitude: 15.6, clock: LobbyClock(timeZone: TimeZone(identifier: "Europe/Oslo")!))
        XCTAssertNil(svalbard.times(on: adelaide(2026, 6, 21, 12)))
        XCTAssertFalse(svalbard.isNight(at: adelaide(2026, 6, 21, 12)))
    }
}
