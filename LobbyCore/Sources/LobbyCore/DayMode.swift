import Foundation

/// Work is up front in work hours, his interests after hours.
public enum DayMode: String, Codable, CaseIterable, Sendable {
    case work
    case offDuty

    public var label: String {
        switch self {
        case .work: return "Work"
        case .offDuty: return "Off duty"
        }
    }
}

/// When Lobby counts as being at work. Weekdays only.
public struct WorkHours: Codable, Equatable, Sendable {
    public var startHour: Int
    public var startMinute: Int
    public var endHour: Int
    public var endMinute: Int

    public static let standard = WorkHours(startHour: 8, startMinute: 30, endHour: 17, endMinute: 0)

    public init(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    public func start(on day: Date, clock: LobbyClock) -> Date {
        clock.date(on: day, hour: startHour, minute: startMinute)
    }

    public func end(on day: Date, clock: LobbyClock) -> Date {
        clock.date(on: day, hour: endHour, minute: endMinute)
    }

    public func mode(at date: Date, clock: LobbyClock) -> DayMode {
        if clock.isWeekend(date) { return .offDuty }
        return (start(on: date, clock: clock)..<end(on: date, clock: clock)).contains(date) ? .work : .offDuty
    }

    /// The next moment the automatic mode flips after `date`.
    public func nextChange(after date: Date, clock: LobbyClock) -> Date {
        var day = clock.startOfDay(date)
        for _ in 0..<8 {
            if !clock.isWeekend(day) {
                for edge in [start(on: day, clock: clock), end(on: day, clock: clock)] where edge > date {
                    return edge
                }
            }
            day = clock.addingDays(1, to: day)
        }
        return clock.addingDays(1, to: date)
    }
}

/// The Work / Off duty toggle. Lobby picks on its own; tapping the toggle
/// overrides it until the next natural change (start or end of the work day).
public struct ModeState: Codable, Equatable, Sendable {
    public var override: DayMode?
    public var overrideUntil: Date?

    public init(override: DayMode? = nil, overrideUntil: Date? = nil) {
        self.override = override
        self.overrideUntil = overrideUntil
    }

    public func mode(at date: Date, hours: WorkHours, clock: LobbyClock) -> DayMode {
        if let override, let until = overrideUntil, date < until { return override }
        return hours.mode(at: date, clock: clock)
    }

    public mutating func choose(_ mode: DayMode, at date: Date, hours: WorkHours, clock: LobbyClock) {
        if mode == hours.mode(at: date, clock: clock) {
            override = nil
            overrideUntil = nil
        } else {
            override = mode
            overrideUntil = hours.nextChange(after: date, clock: clock)
        }
    }
}

public enum Greeting {
    /// "Good morning, Wade". Morning until noon, afternoon until 5pm, then evening.
    public static func text(at date: Date, name: String, clock: LobbyClock) -> String {
        let hour = clock.calendar.component(.hour, from: date)
        let part: String
        switch hour {
        case 0..<12: part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default: part = "Evening"
        }
        return "\(part), \(name)"
    }
}
