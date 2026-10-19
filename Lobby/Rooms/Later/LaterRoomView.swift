import SwiftUI

/// Fleet, Trips and Brand are designed and signed off, and come in later phases.
/// Until then each room says what's coming rather than pretending.
struct LaterRoomView: View {
    @Environment(\.palette) var palette
    let room: Room

    private var phase: Int {
        switch room {
        case .trips: return 3
        case .fleet: return 4
        default: return 5
        }
    }

    private var lines: [String] {
        switch room {
        case .fleet:
            return [
                "Rego bingo for every Qantas aircraft: not yet, spotted, flown.",
                "Rego lookup by typing or pointing the camera.",
                "What's over Adelaide right now, with a ping for your watchlist.",
                "Flight log built from booking emails.",
            ]
        case .trips:
            return [
                "Bookings from personal Gmail, laid out as a trip timeline.",
                "Flight cards with gate and delays.",
                "An ideas board you drag onto days.",
                "Today away replaces Home on trip days.",
            ]
        default:
            return [
                "Superpower line, your week in four slices, anchor values.",
                "Ideas lab with the K.I.L.L.E.R. check and one next step.",
                "This week's story, saved to the story bank.",
                "Habits that tick themselves, goals, presence.",
            ]
        }
    }

    private var tint: Color {
        switch room {
        case .fleet: return palette.peach
        case .trips: return palette.lilac
        default: return palette.mint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoomTitle(kicker: "Phase \(phase)", title: room.label)
                .padding(.horizontal, 6)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 14) {
                Text("Designed, signed off, built in phase \(phase).")
                    .font(.urbanist(22, .bold))
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(palette.ink).frame(width: 6, height: 6).offset(y: -2)
                        Text(line).font(.urbanist(15))
                    }
                }
                Text("The mock-up lives in design/Mac\(room.label).dc.html.")
                    .font(.urbanist(13))
                    .foregroundStyle(palette.muted)
                    .padding(.top, 6)
            }
            .card(tint, padding: 28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }
}
