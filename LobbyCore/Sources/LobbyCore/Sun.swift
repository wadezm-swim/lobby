import Foundation

/// Sunrise and sunset, so Lobby can go light by day and dark at night on its own.
///
/// Uses the standard sunrise equation (accurate to a minute or two, which is plenty
/// for picking a theme). Defaults to Adelaide.
public struct Sun: Sendable {
    public static let adelaide = Sun(latitude: -34.9285, longitude: 138.6007, clock: .adelaide)

    public let latitude: Double
    public let longitude: Double
    public let clock: LobbyClock

    public init(latitude: Double, longitude: Double, clock: LobbyClock) {
        self.latitude = latitude
        self.longitude = longitude
        self.clock = clock
    }

    public struct Times: Equatable, Sendable {
        public let sunrise: Date
        public let sunset: Date
    }

    /// Sunrise and sunset on the local day containing `date`, or nil where the sun
    /// doesn't rise or set that day (polar regions).
    public func times(on date: Date) -> Times? {
        // Julian date of 12:00 UTC on the local calendar day.
        let c = clock.calendar.dateComponents([.year, .month, .day], from: date)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let noonUTC = utc.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: 12)) else {
            return nil
        }
        // Julian days start at noon, so this is a whole number of days since J2000.
        let julianDate = noonUTC.timeIntervalSince1970 / 86400 + 2440587.5
        let n = (julianDate - 2451545.0).rounded()

        let meanSolarTime = n + 0.0008 - longitude / 360
        let anomaly = (357.5291 + 0.98560028 * meanSolarTime).truncatingRemainder(dividingBy: 360)
        let m = anomaly * .pi / 180
        let centre = 1.9148 * sin(m) + 0.0200 * sin(2 * m) + 0.0003 * sin(3 * m)
        let eclipticLongitude = (anomaly + centre + 180 + 102.9372).truncatingRemainder(dividingBy: 360)
        let lambda = eclipticLongitude * .pi / 180
        let transit = 2451545.0 + meanSolarTime + 0.0053 * sin(m) - 0.0069 * sin(2 * lambda)

        let sinDeclination = sin(lambda) * sin(23.4397 * .pi / 180)
        let declination = asin(sinDeclination)
        let phi = latitude * .pi / 180
        let cosHourAngle = (sin(-0.833 * .pi / 180) - sin(phi) * sinDeclination) / (cos(phi) * cos(declination))
        guard (-1...1).contains(cosHourAngle) else { return nil }
        let hourAngle = acos(cosHourAngle) * 180 / .pi

        func toDate(_ julian: Double) -> Date {
            Date(timeIntervalSince1970: (julian - 2440587.5) * 86400)
        }
        return Times(sunrise: toDate(transit - hourAngle / 360), sunset: toDate(transit + hourAngle / 360))
    }

    /// True between sunset and the next sunrise.
    public func isNight(at date: Date) -> Bool {
        guard let t = times(on: date) else { return false }
        return date < t.sunrise || date >= t.sunset
    }
}
