import SwiftUI
import LobbyCore

/// Home: "Looking forward to", then the cards. Work cards lead in work hours,
/// his interests lead after hours.
struct HomeView: View {
    @Environment(AppModel.self) var model

    private enum CardID: CaseIterable {
        case nextUp, topThree, sports, body, fleet, trip, quiz
    }

    private var order: [CardID] {
        switch model.mode {
        case .work: return [.nextUp, .topThree, .sports, .body, .fleet, .trip, .quiz]
        case .offDuty: return [.sports, .trip, .quiz, .fleet, .body, .nextUp, .topThree]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HomeHeader()
            CardGrid(minColumnWidth: 260, spacing: 20) {
                ForEach(order, id: \.self) { id in
                    switch id {
                    case .nextUp: NextUpCard()
                    case .topThree: TopThreeCard()
                    case .sports: SportsCountdownCard()
                    case .body: BodyCard()
                    case .fleet: FleetCard()
                    case .trip: TripCard()
                    case .quiz: QuizCard()
                    }
                }
            }
        }
    }
}

struct HomeHeader: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                RoomTitle(kicker: model.dateLine, title: model.greeting)
                if let forward = model.lookingForward {
                    HStack(spacing: 8) {
                        Text("Looking forward to")
                            .font(.urbanist(12, .bold))
                            .foregroundStyle(Color(hex: "#0E0E0E"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Palette.day.lilac, in: Capsule())
                        Text(forward).font(.urbanist(14, .semibold))
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 14)
                    .padding(.vertical, 6)
                    .background(palette.card, in: Capsule())
                    .padding(.top, 10)
                }
            }
            Spacer(minLength: 16)
            HStack(spacing: 10) {
                Button { ConciergeController.shared.show() } label: {
                    HStack {
                        Text("Search or capture  ⌥ Space")
                            .font(.urbanist(15, .medium))
                            .foregroundStyle(palette.muted)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 20)
                    .frame(width: 260, height: 48)
                    .background(palette.card, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search or capture")

                PillPicker(
                    options: DayMode.allCases.map { (label: $0.label, value: $0) },
                    selection: model.mode,
                    background: palette.card,
                    selectedFill: palette.isDark ? palette.lime : Color(hex: "#0E0E0E"),
                    selectedText: palette.isDark ? Color(hex: "#0E0E0E") : .white,
                    text: palette.ink
                ) { model.setMode($0) }

                Text(String(model.snapshot.ownerName.prefix(1)))
                    .font(.urbanist(15, .bold))
                    .foregroundStyle(Color(hex: "#0E0E0E"))
                    .frame(width: 48, height: 48)
                    .background(Palette.day.lilac, in: Circle())
                    .accessibilityLabel(model.snapshot.ownerName)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
    }
}

// MARK: - Cards

struct NextUpCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let meeting = model.nextMeeting
        Button { model.room = .work } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label(for: meeting)).font(.urbanist(15, .semibold))
                    Spacer()
                    ArrowBadge()
                }
                Spacer(minLength: 24)
                if let meeting {
                    Text(model.clock.clock(meeting.start))
                        .font(.urbanist(72, .bold))
                        .tracking(-2.9)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(meeting.title).font(.urbanist(18, .semibold)).lineLimit(2)
                    Text(detail(for: meeting)).font(.urbanist(14))
                } else {
                    Text("Clear").font(.urbanist(72, .bold)).tracking(-2.9)
                    Text("Nothing else in the diary").font(.urbanist(18, .semibold))
                }
            }
            .foregroundStyle(palette.onLime)
            .card(palette.lime, minHeight: 220)
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }

    private func label(for meeting: Meeting?) -> String {
        guard let meeting else { return "Next up" }
        if meeting.start <= model.now { return "On now" }
        if model.clock.startOfDay(meeting.start) != model.clock.startOfDay(model.now) {
            return "Next up · \(model.clock.weekdayName(meeting.start))"
        }
        return "Next up · \(Countdown.relative(from: model.now, to: meeting.start))"
    }

    private func detail(for meeting: Meeting) -> String {
        [meeting.location, Countdown.duration(minutes: meeting.minutes)].compactMap { $0 }.joined(separator: " · ")
    }
}

struct TopThreeCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(model.snapshot.topThree.count)").font(.urbanist(48, .bold)).tracking(-1.4)
                Text("things today").font(.urbanist(15, .semibold))
            }
            ForEach(model.snapshot.topThree) { item in
                CheckRow(title: item.title, done: item.done) { model.toggleTask(item.id) }
            }
        }
        .card(palette.card)
    }
}

struct SportsCountdownCard: View {
    @Environment(AppModel.self) var model

    var body: some View {
        Button { model.room = .sports } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.urbanist(15, .semibold))
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: model.team.colorHex)).frame(width: 8, height: 8)
                        Text("Your team").font(.urbanist(13))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#222222"), in: Capsule())
                }
                Spacer(minLength: 24)
                Text(kicker).font(.urbanist(14)).foregroundStyle(Palette.sportsSecondary)
                Text(countdown).font(.urbanist(52, .bold)).tracking(-1.5).lineLimit(1).minimumScaleFactor(0.6)
                Text(footnote).font(.urbanist(14)).foregroundStyle(Palette.sportsSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(alignment: .topTrailing) {
                Glow(color: Color(hex: model.team.colorHex), size: 260, blur: 70, opacity: 0.55)
                    .offset(x: 114, y: -134)
            }
            .foregroundStyle(.white)
            .card(Color(hex: "#0E0E0E"), minHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }

    private var weekend: F1Weekend? { model.currentWeekend }
    private var session: F1Session? { weekend?.nextSession(after: model.now) }

    private var title: String { weekend?.shortName ?? "F1 off-season" }

    private var kicker: String {
        if let session { return "\(session.kind.label) in" }
        return weekend == nil ? "Pre-season testing in" : "Racing now"
    }

    private var countdown: String {
        guard let session else { return weekend == nil ? "[n] days" : "Live" }
        return Countdown.short(from: model.now, to: session.start)
    }

    private var footnote: String {
        guard let session else { return "Spoiler shield is on until you watch" }
        var parts = [model.clock.dayAndTime(session.start)]
        if let race = weekend?.race, race.alarm != nil {
            parts.append("race alarm set for \(model.clock.shortWeekdayName(race.start))")
        }
        return parts.joined(separator: " · ")
    }
}

struct BodyCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardHeader(title: "Body", trailing: "from Apple Health")
            FlowLayout(spacing: 8) {
                ForEach(model.snapshot.body.chips, id: \.self) { chip in
                    Chip(text: chip.text, fill: chip.highlighted ? palette.lime : palette.fill,
                         ink: chip.highlighted ? palette.onLime : palette.ink)
                }
            }
            Text("Tomorrow: \(model.snapshot.body.tomorrow)")
                .font(.urbanist(13))
                .foregroundStyle(palette.muted)
        }
        .card(palette.card)
    }
}

struct FleetCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let fleet = model.snapshot.fleet
        Button { model.room = .fleet } label: {
            HStack(spacing: 18) {
                FleetRing(flown: fleet.flown, spotted: fleet.spotted, total: fleet.total)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fleet bingo").font(.urbanist(18, .bold))
                    Text("\(fleet.flown) flown · \(fleet.spotted) spotted").font(.urbanist(14)).foregroundStyle(palette.muted)
                    Text(fleet.latest).font(.urbanist(13)).foregroundStyle(palette.muted).padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
            .card(palette.card)
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }
}

/// Qantas red for flown, a lighter red for spotted, grey for the rest.
struct FleetRing: View {
    @Environment(\.palette) var palette
    let flown: Int
    let spotted: Int
    let total: Int

    var body: some View {
        let flownShare = total > 0 ? Double(flown) / Double(total) : 0
        let spottedShare = total > 0 ? Double(spotted) / Double(total) : 0
        ZStack {
            Circle().stroke(palette.isDark ? Color(hex: "#2A2A2A") : Color(hex: "#EDEDED"), lineWidth: 11)
            Circle()
                .trim(from: flownShare, to: min(1, flownShare + spottedShare))
                .stroke(Color(hex: "#FFB3B3"), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: flownShare)
                .stroke(Color(hex: "#E40000"), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(6)
        .accessibilityElement()
        .accessibilityLabel("\(flown) of \(total) flown, \(spotted) spotted")
    }
}

struct TripCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        Button { model.room = .trips } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next trip").font(.urbanist(15, .semibold))
                Spacer(minLength: 24)
                if let trip = model.nextTrip {
                    Text(trip.name).font(.urbanist(34, .bold)).tracking(-0.7)
                    Text("\(trip.flight) · \(model.clock.calendarDays(from: model.now, to: trip.departs)) days")
                        .font(.urbanist(14))
                } else {
                    Text("Nothing booked").font(.urbanist(34, .bold)).tracking(-0.7)
                    Text("Bookings show up here from Gmail").font(.urbanist(14))
                }
            }
            .card(palette.lilac)
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
    }
}

struct QuizCard: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        let questions = model.quizToday
        let index = model.quizIndex
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily three").font(.urbanist(18, .bold))
                Spacer()
                if index < questions.count {
                    Text("\(index + 1) of \(questions.count)").font(.urbanist(13)).foregroundStyle(palette.skyMuted)
                }
            }
            if index < questions.count {
                question(questions[index], index: index)
            } else {
                Text("Done for today.").font(.urbanist(15, .semibold))
                Text(streakLine).font(.urbanist(13)).foregroundStyle(palette.skyMuted)
            }
        }
        .card(palette.sky)
    }

    @ViewBuilder
    private func question(_ question: QuizQuestion, index: Int) -> some View {
        let picked = model.quizFeedback?.index == index ? model.quizFeedback?.picked : nil
        Text(question.prompt).font(.urbanist(15, .semibold))
        FlowLayout(spacing: 8) {
            ForEach(question.options, id: \.self) { option in
                Button { model.answerQuiz(option) } label: {
                    Text(picked != nil && option == question.answer ? "\(option) ✓" : option)
                        .font(.urbanist(14, .bold))
                        .foregroundStyle(Color(hex: "#0E0E0E"))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(fill(for: option, picked: picked, answer: question.answer), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(picked != nil)
            }
        }
        if let picked {
            let right = picked == question.answer
            HStack(alignment: .firstTextBaseline) {
                Text(right
                     ? "Right. \(question.note) Streak: \(model.quizStreak) \(model.quizStreak == 1 ? "day" : "days")."
                     : "Not quite. It's \(question.answer). Streak resets tomorrow.")
                    .font(.urbanist(13))
                    .foregroundStyle(palette.skyMuted)
                Spacer(minLength: 8)
                Button(index + 1 < model.quizToday.count ? "Next" : "Done") { model.nextQuizQuestion() }
                    .buttonStyle(.plain)
                    .font(.urbanist(13, .bold))
                    .foregroundStyle(palette.ink)
            }
        } else {
            Text("Aviation, F1 and Port questions from your own world.")
                .font(.urbanist(13))
                .foregroundStyle(palette.skyMuted)
        }
    }

    private func fill(for option: String, picked: String?, answer: String) -> Color {
        guard let picked else { return .white }
        if option == answer { return Palette.day.mint }
        if option == picked { return Palette.day.peach }
        return .white
    }

    private var streakLine: String {
        let streak = model.quizStreak
        if model.quizAnswers.contains(false) { return "One got away. Streak resets tomorrow." }
        return "Streak: \(streak) \(streak == 1 ? "day" : "days"). Back tomorrow with three more."
    }
}
