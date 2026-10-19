import Foundation
@testable import LobbyCore

let clock = LobbyClock.adelaide

/// A moment in Adelaide time.
func adelaide(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    clock.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// A moment in UTC, as Jolpica gives session times.
func utc(_ iso: String) -> Date {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: iso)!
}

/// Monday 19 October 2026, 9:50am: the morning of the handover.
let handoverMorning = adelaide(2026, 10, 19, 9, 50)
