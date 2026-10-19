import Foundation

/// The countdown strings used across Lobby.
public enum Countdown {
    /// Days, hours and minutes left, rounded down. Negative spans count as zero.
    public struct Parts: Equatable, Sendable {
        public let days: Int
        public let hours: Int
        public let minutes: Int
    }

    public static func parts(from: Date, to: Date) -> Parts {
        let total = max(0, Int(to.timeIntervalSince(from)) / 60)
        return Parts(days: total / 1440, hours: (total % 1440) / 60, minutes: total % 60)
    }

    /// "4d 18h" when a day or more out, "5h 20m" within a day, "40 min" within an hour.
    public static func short(from: Date, to: Date) -> String {
        let p = parts(from: from, to: to)
        if p.days > 0 { return "\(p.days)d \(p.hours)h" }
        if p.hours > 0 { return "\(p.hours)h \(p.minutes)m" }
        return "\(p.minutes) min"
    }

    /// "6:10:50" as days, hours, minutes. The F1 hero uses this.
    public static func clock(from: Date, to: Date) -> String {
        let p = parts(from: from, to: to)
        return String(format: "%d:%02d:%02d", p.days, p.hours, p.minutes)
    }

    /// "in 40 min", "in 2h 5m", "now" once it has started, "tomorrow" style is left to the caller.
    public static func relative(from: Date, to: Date) -> String {
        if to <= from { return "now" }
        let p = parts(from: from, to: to)
        if p.days == 0 && p.hours == 0 && p.minutes == 0 { return "in under a minute" }
        return "in " + short(from: from, to: to)
    }

    /// "30 min", "1 hr", "1 hr 30 min".
    public static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }
}
