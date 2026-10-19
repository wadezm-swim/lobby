import SwiftUI
import LobbyCore

/// Work: today's meetings, top three, waiting on, Notion projects, the Friday
/// log and a capture box.
struct WorkView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RoomTitle(kicker: model.dateLine, title: "Work")
                .padding(.horizontal, 6)
                .padding(.top, 8)
            CardGrid(minColumnWidth: 260, spacing: 20) {
                TodayCard()
                WorkTopThreeCard()
                WaitingOnCard()
                ProjectsCard()
                WeeklyLogCard()
                CaptureCard()
            }
        }
    }
}

struct TodayCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let meetings = model.todaysMeetings
        let current = model.nextMeeting
        VStack(alignment: .leading, spacing: 4) {
            CardHeader(title: "Today").padding(.bottom, 8)
            if meetings.isEmpty {
                Text(model.clock.isWeekend(model.now) ? "It's the weekend. The diary agrees." : "Nothing in the diary today.")
                    .font(.urbanist(14))
                    .foregroundStyle(palette.muted)
            }
            ForEach(meetings) { meeting in
                let highlighted = meeting.id == current?.id
                HStack(alignment: .center, spacing: 0) {
                    Text(model.clock.clock(meeting.start))
                        .font(.urbanist(15, highlighted ? .bold : .medium))
                        .frame(width: 76, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.title).font(.urbanist(15, .semibold))
                        Text(detail(for: meeting, highlighted: highlighted))
                            .font(.urbanist(13))
                            .foregroundStyle(highlighted ? palette.onLime : palette.muted)
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(highlighted ? palette.onLime : palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(highlighted ? palette.lime : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(meeting.end <= model.now ? 0.45 : 1)
            }
        }
        .card(palette.card)
    }

    private func detail(for meeting: Meeting, highlighted: Bool) -> String {
        var parts: [String] = []
        if let location = meeting.location { parts.append(location) }
        if let note = meeting.note { parts.append(note) }
        if highlighted && meeting.start > model.now {
            parts.append(Countdown.relative(from: model.now, to: meeting.start))
        } else if meeting.location != nil {
            parts.append(Countdown.duration(minutes: meeting.minutes))
        }
        return parts.joined(separator: " · ")
    }
}

struct WorkTopThreeCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Top three", trailing: "Proposed this morning")
            ForEach(model.snapshot.topThree) { item in
                CheckRow(title: item.title, done: item.done) { model.toggleTask(item.id) }
            }
            Button { model.swapOne() } label: {
                Text("Swap one")
                    .font(.urbanist(14, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .background(Color(hex: "#0E0E0E"), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .card(palette.card)
    }
}

struct WaitingOnCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let items = model.snapshot.waitingOn
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(title: "Waiting on", trailing: "\(items.count)")
            ForEach(items) { item in
                let stale = item.isStale(at: model.now, clock: model.clock)
                let nudged = item.nudgedAt.map { model.clock.startOfDay($0) == model.clock.startOfDay(model.now) } ?? false
                HStack(spacing: 12) {
                    Text(item.initials)
                        .font(.urbanist(15, .bold))
                        .foregroundStyle(Color(hex: "#0E0E0E"))
                        .frame(width: 40, height: 40)
                        .background(tint(item.tint), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.what).font(.urbanist(15, .semibold))
                        let days = model.clock.calendarDays(from: item.since, to: model.now)
                        Text(days == 0 ? "today" : days == 1 ? "1 day" : "\(days) days")
                            .font(.urbanist(13))
                            .foregroundStyle(stale ? Color(hex: "#C2410C") : palette.muted)
                    }
                    Spacer(minLength: 8)
                    Button { model.nudge(item.id) } label: {
                        Text(nudged ? "Nudged" : "Nudge")
                            .font(.urbanist(13, .bold))
                            .foregroundStyle(stale && !nudged ? .white : palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(stale && !nudged ? Color(hex: "#0E0E0E") : palette.fill, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(nudged)
                }
            }
            Text("From sent mail if IT approves; otherwise you add one with a tap.")
                .font(.urbanist(12))
                .foregroundStyle(palette.muted)
        }
        .card(palette.card)
    }

    private func tint(_ tint: Tint) -> Color {
        switch tint {
        case .lime: return Palette.day.lime
        case .lilac: return Palette.day.lilac
        case .sky: return Palette.day.sky
        case .mint: return Palette.day.mint
        case .peach: return Palette.day.peach
        }
    }
}

struct ProjectsCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(title: "Projects", trailing: "from Notion")
            ForEach(model.snapshot.projects) { project in
                HStack(spacing: 10) {
                    Text(project.name).font(.urbanist(15, .medium))
                    Spacer(minLength: 8)
                    Text(project.nextStep)
                        .font(.urbanist(13, .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(palette.fill, in: Capsule())
                }
            }
        }
        .card(palette.card)
    }
}

struct WeeklyLogCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let ready = WeeklyLog.isReady(at: model.now, clock: model.clock)
        VStack(alignment: .leading, spacing: 6) {
            Text("Weekly log").font(.urbanist(15, .semibold))
            Spacer(minLength: 40)
            Text(ready ? "This week, written" : "Ready Friday, 3pm")
                .font(.urbanist(30, .bold))
                .tracking(-0.6)
            Text(ready
                 ? "Lands in Notion once the cloud is on. Nothing to fill in."
                 : "Written for you from your week. Nothing to fill in.")
                .font(.urbanist(14))
        }
        .card(palette.lilac, minHeight: 200)
    }
}

struct CaptureCard: View {
    @Environment(AppModel.self) var model
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capture").font(.urbanist(18, .bold))
            Text(model.queuedCaptureCount == 0
                 ? "Kept on this Mac for now. Notion filing arrives with the phone build."
                 : "Kept on this Mac for now · \(model.queuedCaptureCount) saved. Notion filing arrives with the phone build.")
                .font(.urbanist(13))
                .foregroundStyle(Palette.sportsSecondary)
            TextField("", text: $text, prompt: Text("Type or press ⌥ Space anywhere").foregroundStyle(Color(hex: "#7A7A7F")))
                .textFieldStyle(.plain)
                .font(.urbanist(15, .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(Color(hex: "#222222"), in: Capsule())
                .padding(.top, 8)
                .onSubmit {
                    model.quickCapture(text)
                    text = ""
                }
        }
        .foregroundStyle(.white)
        .card(Color(hex: "#0E0E0E"))
    }
}
