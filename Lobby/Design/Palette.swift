import SwiftUI

/// Colours from the design files. Light by day, dark at night, and the Sports
/// room is always dark.
struct Palette {
    var canvas: Color
    var card: Color
    var ink: Color
    var muted: Color
    /// The grey behind checklist rows and chips.
    var fill: Color
    /// Unticked checkbox ring.
    var ring: Color
    var divider: Color
    var lime: Color
    var onLime: Color
    var lilac: Color
    var sky: Color
    var skyMuted: Color
    var mint: Color
    var peach: Color
    /// The black card on a light canvas (sports countdown, capture).
    var inverse: Color
    var onInverse: Color
    var inverseMuted: Color
    var isDark: Bool

    static let day = Palette(
        canvas: Color(hex: "#ECECEC"),
        card: .white,
        ink: Color(hex: "#0E0E0E"),
        muted: Color(hex: "#5F5F64"),
        fill: Color(hex: "#F4F4F4"),
        ring: Color(hex: "#C9C9CE"),
        divider: Color(hex: "#E4E4E7"),
        lime: Color(hex: "#D4FF3F"),
        onLime: Color(hex: "#0E0E0E"),
        lilac: Color(hex: "#E7D9FF"),
        sky: Color(hex: "#CFE7FF"),
        skyMuted: Color(hex: "#3A4B5C"),
        mint: Color(hex: "#CDF5DC"),
        peach: Color(hex: "#FFE1CC"),
        inverse: Color(hex: "#0E0E0E"),
        onInverse: .white,
        inverseMuted: Color(hex: "#B5B5BA"),
        isDark: false
    )

    /// Night keeps the lime and darkens the pastels so they still read as themselves.
    static let night = Palette(
        canvas: .black,
        card: Color(hex: "#141414"),
        ink: Color(hex: "#F5F5F5"),
        muted: Color(hex: "#9B9B9F"),
        fill: Color(hex: "#1E1E1E"),
        ring: Color(hex: "#3A3A3A"),
        divider: Color(hex: "#222222"),
        lime: Color(hex: "#D4FF3F"),
        onLime: Color(hex: "#0E0E0E"),
        lilac: Color(hex: "#251F33"),
        sky: Color(hex: "#152330"),
        skyMuted: Color(hex: "#9DB3C7"),
        mint: Color(hex: "#15281D"),
        peach: Color(hex: "#33241A"),
        inverse: Color(hex: "#1A1A1A"),
        onInverse: .white,
        inverseMuted: Color(hex: "#B5B5BA"),
        isDark: true
    )

    static let sports = Palette(
        canvas: .black,
        card: Color(hex: "#111111"),
        ink: Color(hex: "#F5F5F5"),
        muted: Color(hex: "#9B9B9F"),
        fill: Color(hex: "#1A1A1A"),
        ring: Color(hex: "#3A3A3A"),
        divider: Color(hex: "#222222"),
        lime: Color(hex: "#D4FF3F"),
        onLime: Color(hex: "#0E0E0E"),
        lilac: Color(hex: "#251F33"),
        sky: Color(hex: "#152330"),
        skyMuted: Color(hex: "#9DB3C7"),
        mint: Color(hex: "#15281D"),
        peach: Color(hex: "#33241A"),
        inverse: Color(hex: "#1A1A1A"),
        onInverse: .white,
        inverseMuted: Color(hex: "#B5B5BA"),
        isDark: true
    )

    /// Light grey text on dark sports cards.
    static let sportsSecondary = Color(hex: "#B5B5BA")
    static let f1Red = Color(hex: "#E10600")
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.day
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    /// "#RRGGBB". Anything unreadable comes out grey rather than crashing.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0x888888
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
