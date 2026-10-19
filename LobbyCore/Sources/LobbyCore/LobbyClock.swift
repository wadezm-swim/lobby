import Foundation

/// Adelaide time and the few ways Lobby writes dates and times.
///
/// Formatting is done by hand rather than with `DateFormatter` so the output is
/// identical on every platform and locale ("4:00am", never "4:00 AM").
public struct LobbyClock: Sendable {
    public static let adelaide = LobbyClock(timeZone: TimeZone(identifier: "Australia/Adelaide")!)

    public let timeZone: TimeZone
    public let calendar: Calendar

    public init(timeZone: TimeZone) {
        self.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2 // Monday
        calendar.locale = Locale(identifier: "en_AU")
        self.calendar = calendar
    }

    static let shortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static let longWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    static let longMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    // MARK: Building dates

    /// A date at `hour:minute` on the same Adelaide day as `day`.
    public func date(on day: Date, hour: Int, minute: Int = 0) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start) ?? start
    }

    public func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// Whole calendar days from `from` to `to` in Adelaide, ignoring the time of day.
    public func calendarDays(from: Date, to: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(from), to: startOfDay(to)).day ?? 0
    }

    /// 1 = Sunday ... 7 = Saturday, as `Calendar` counts them.
    public func weekday(_ date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    public func isWeekend(_ date: Date) -> Bool {
        let day = weekday(date)
        return day == 1 || day == 7
    }

    /// The next date (strictly after the day of `date`, unless `includingToday`) that falls on `weekday`.
    public func next(weekday target: Int, after date: Date, includingToday: Bool = false) -> Date {
        let today = weekday(date)
        var ahead = (target - today + 7) % 7
        if ahead == 0 && !includingToday { ahead = 7 }
        return addingDays(ahead, to: startOfDay(date))
    }

    /// A stable key for an Adelaide day, like "2026-10-19".
    public func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: Writing times

    private func hourMinute(_ date: Date) -> (hour: Int, minute: Int) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0, c.minute ?? 0)
    }

    /// "10:30", "1:30". Twelve-hour, no am/pm, as the meeting lists show it.
    public func clock(_ date: Date) -> String {
        let (h, m) = hourMinute(date)
        let twelve = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d", twelve, m)
    }

    /// "4:00am", "7:30pm".
    public func clockWithSuffix(_ date: Date) -> String {
        let (h, _) = hourMinute(date)
        return clock(date) + (h < 12 ? "am" : "pm")
    }

    /// "Sat 4:00am".
    public func dayAndTime(_ date: Date) -> String {
        "\(Self.shortWeekdays[weekday(date) - 1]) \(clockWithSuffix(date))"
    }

    /// "Thu 22 Oct".
    public func shortDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(Self.shortWeekdays[weekday(date) - 1]) \(c.day ?? 0) \(Self.shortMonths[(c.month ?? 1) - 1])"
    }

    /// "Monday 19 October".
    public func longDate(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(Self.longWeekdays[weekday(date) - 1]) \(c.day ?? 0) \(Self.longMonths[(c.month ?? 1) - 1])"
    }

    /// "Thursday".
    public func weekdayName(_ date: Date) -> String {
        Self.longWeekdays[weekday(date) - 1]
    }

    /// "Thu".
    public func shortWeekdayName(_ date: Date) -> String {
        Self.shortWeekdays[weekday(date) - 1]
    }
}
