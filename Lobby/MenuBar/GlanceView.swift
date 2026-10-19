import AppKit
import SwiftUI
import LobbyCore

/// What sits in the menu bar: a lime dot and the next thing.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
            Text(model.menuBarTitle)
        }
    }
}

/// The menu bar glance: next up, top three, countdown, waiting on, now playing
/// and a capture box.
struct GlanceView: View {
    @Environment(AppModel.self) var model
    @Environment(\.openWindow) private var openWindow
    @State private var text = ""

    private var palette: Palette { model.isNight ? .night : .day }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lobby").font(.urbanist(18, .heavy))
                Spacer()
                Text(model.mode.label)
                    .font(.urbanist(12, .semibold))
                    .foregroundStyle(palette.isDark ? Color(hex: "#0E0E0E") : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(palette.isDark ? palette.lime : Color(hex: "#0E0E0E"), in: Capsule())
            }
            .padding(.horizontal, 4)

            nextUp

            VStack(alignment: .leading, spacing: 8) {
                Text("Top three").font(.urbanist(14, .bold))
                ForEach(model.snapshot.topThree) { item in
                    CheckRow(title: item.title, done: item.done, compact: true) { model.toggleTask(item.id) }
                }
            }
            .padding(14)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(countdownLabel).font(.urbanist(12)).foregroundStyle(Palette.sportsSecondary)
                    Text(countdownValue).font(.urbanist(20, .bold)).foregroundStyle(.white)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#0E0E0E"), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Waiting on").font(.urbanist(12)).foregroundStyle(palette.muted)
                    Text("\(model.snapshot.waitingOn.count)").font(.urbanist(20, .bold))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if let playing = model.snapshot.nowPlaying {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(palette.mint)
                        .frame(width: 40, height: 40)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Now playing · \(playing.source)").font(.urbanist(12)).foregroundStyle(palette.muted)
                        Text(playing.title).font(.urbanist(14, .bold)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: playing.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#0E0E0E"), in: Circle())
                        .accessibilityLabel(playing.isPlaying ? "Pause" : "Play")
                        .help("Playback control arrives with Spotify")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if let toast = model.toast {
                Text(toast).font(.urbanist(12, .semibold)).foregroundStyle(palette.muted).padding(.horizontal, 4)
            }

            TextField("", text: $text, prompt: Text("Capture, then press Return").foregroundStyle(palette.muted))
                .textFieldStyle(.plain)
                .font(.urbanist(14, .medium))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(palette.card, in: Capsule())
                .onSubmit {
                    model.quickCapture(text)
                    text = ""
                }

            Button("Open Lobby") {
                openWindow(id: "main")
                NSApp.activate()
            }
            .buttonStyle(.plain)
            .font(.urbanist(13, .semibold))
            .underline()
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 368)
        .background(palette.canvas)
        .foregroundStyle(palette.ink)
        .environment(\.palette, palette)
        .preferredColorScheme(palette.isDark ? .dark : .light)
    }

    @ViewBuilder
    private var nextUp: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let meeting = model.nextMeeting {
                Text(meeting.start <= model.now ? "On now" : "Next up · \(Countdown.relative(from: model.now, to: meeting.start))")
                    .font(.urbanist(13, .semibold))
                Text(model.clock.clock(meeting.start)).font(.urbanist(40, .bold)).tracking(-1.2)
                Text([meeting.title, meeting.location].compactMap { $0 }.joined(separator: " · "))
                    .font(.urbanist(15, .semibold))
                    .lineLimit(1)
            } else {
                Text("Next up").font(.urbanist(13, .semibold))
                Text("Clear").font(.urbanist(40, .bold))
            }
        }
        .foregroundStyle(palette.onLime)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.lime, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var countdownLabel: String {
        guard let weekend = model.currentWeekend, let session = weekend.nextSession(after: model.now) else { return "F1" }
        return "\(weekend.shortName) \(session.kind.label.lowercased())"
    }

    private var countdownValue: String {
        guard let weekend = model.currentWeekend, let session = weekend.nextSession(after: model.now) else {
            return model.currentWeekend == nil ? "Off-season" : "Live"
        }
        return Countdown.short(from: model.now, to: session.start)
    }
}
