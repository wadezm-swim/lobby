import SwiftUI
import LobbyCore

/// Sports is always dark. F1 and AFL, each with his team first.
struct SportsView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text("Sports").font(.urbanist(44, .bold)).tracking(-0.9)
                Spacer()
                PillPicker(
                    options: [(label: "F1", value: AppModel.Sport.f1), (label: "AFL", value: AppModel.Sport.afl)],
                    selection: model.sport,
                    background: Color(hex: "#141414"),
                    selectedFill: Color(hex: "#F5F5F5"),
                    selectedText: Color(hex: "#0E0E0E"),
                    text: Palette.sportsSecondary
                ) { model.sport = $0 }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)

            switch model.sport {
            case .f1: F1Room()
            case .afl: AFLRoom()
            }
        }
    }
}

// MARK: - F1

struct F1Room: View {
    @Environment(AppModel.self) var model

    var body: some View {
        let content = model.f1
        let teamColor = Color(hex: model.team.colorHex)
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                FlowLayout(spacing: 8) {
                    ForEach(F1Team.all) { team in
                        TeamChip(team: team, selected: team.id == model.team.id) { model.selectTeam(team.id) }
                    }
                }
                if model.snapshot.isSample {
                    PillPicker(
                        options: [(label: "Race week", value: F1Phase.raceWeek), (label: "Off-season", value: F1Phase.offSeason)],
                        selection: content.phase,
                        background: Color(hex: "#141414"),
                        selectedFill: Color(hex: "#F5F5F5"),
                        selectedText: Color(hex: "#0E0E0E"),
                        text: Palette.sportsSecondary
                    ) { phase in
                        model.f1PreviewPhase = phase == model.snapshot.f1Calendar.phase(at: model.now) ? nil : phase
                    }
                    .help("Preview, while Lobby runs on sample data")
                }
            }

            HStack(alignment: .top, spacing: 18) {
                F1Hero(content: content, teamColor: teamColor)
                TeamCard(content: content, team: model.team, teamColor: teamColor)
                    .frame(width: 330)
            }
            .fixedSize(horizontal: false, vertical: true)

            CardGrid(minColumnWidth: 280, spacing: 18) {
                SessionsCard(content: content)
                NewsWireCard(items: content.news, subtitle: "your team first")
                ShieldCard(content: content)
                PicksCard()
            }
        }
    }
}

struct TeamChip: View {
    let team: F1Team
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: team.colorHex)).frame(width: 10, height: 10)
                Text(team.name).font(.urbanist(13, .semibold)).foregroundStyle(Color(hex: "#F5F5F5"))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(selected ? Color(hex: "#1F1F1F") : .clear, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? Color(hex: team.colorHex) : Color(hex: "#2A2A2A"), lineWidth: 1.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The F1 badge: red, italic, with a slanted right edge.
struct F1Badge: View {
    var body: some View {
        Text("F1")
            .font(.titillium(18, .black))
            .italic()
            .foregroundStyle(.white)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 6)
            .background(Palette.f1Red)
            .clipShape(SlantedEdge())
            .accessibilityLabel("Formula 1")
    }
}

struct SlantedEdge: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct F1Hero: View {
    let content: F1RoomContent
    let teamColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                F1Badge()
                Text(content.heroLabel.uppercased())
                    .font(.titillium(14, .bold))
                    .tracking(1.7)
                    .foregroundStyle(Palette.sportsSecondary)
            }
            Spacer(minLength: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(content.countLabel).font(.urbanist(14)).foregroundStyle(Color(hex: "#9B9B9F"))
                Text(content.countValue)
                    .font(.titillium(92, .black))
                    .tracking(-1.8)
                    .foregroundStyle(teamColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(content.countSub).font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, minHeight: 340, maxHeight: .infinity, alignment: .topLeading)
        .background(alignment: .bottomLeading) {
            Text(content.watermark)
                .font(.titillium(180, .black))
                .italic()
                .foregroundStyle(Color(hex: "#1A1A1A"))
                .lineLimit(1)
                .fixedSize()
                .offset(x: 10, y: 40)
                .accessibilityHidden(true)
        }
        .background(alignment: .topTrailing) {
            Glow(color: teamColor).offset(x: 120, y: -180)
        }
        .background(Color(hex: "#111111"))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct TeamCard: View {
    let content: F1RoomContent
    let team: F1Team
    let teamColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(teamColor).frame(height: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text("Your team").font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
                Text(team.name.uppercased()).font(.titillium(30, .black)).lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(spacing: 10) {
                ForEach(Array(team.drivers.prefix(2).enumerated()), id: \.offset) { index, driver in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(driver).font(.titillium(18, .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        Text(index < content.driverLines.count ? content.driverLines[index] : "")
                            .font(.urbanist(12))
                            .foregroundStyle(Color(hex: "#9B9B9F"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#1A1A1A"), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            Spacer(minLength: 12)
            Text(content.teamNote).font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
        }
        .card(Color(hex: "#111111"))
    }
}

struct SessionsCard: View {
    let content: F1RoomContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(content.panelTitle).font(.urbanist(18, .bold)).padding(.bottom, 8)
            ForEach(Array(content.panelRows.enumerated()), id: \.offset) { _, row in
                DividedRow(label: row.label, value: row.value)
            }
        }
        .card(Color(hex: "#111111"), padding: 22)
    }
}

struct NewsWireCard: View {
    let items: [NewsItem]
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("News wire").font(.urbanist(18, .bold))
                Spacer()
                if let subtitle {
                    Text(subtitle).font(.urbanist(12)).foregroundStyle(Color(hex: "#9B9B9F"))
                }
            }
            .padding(.bottom, 8)
            if items.isEmpty {
                Text("Quiet on the wire.").font(.urbanist(14)).foregroundStyle(Color(hex: "#9B9B9F")).padding(.vertical, 10)
            }
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Rectangle().fill(Color(hex: "#222222")).frame(height: 1).padding(.bottom, 10)
                    Text(item.source).font(.urbanist(12)).foregroundStyle(Color(hex: "#9B9B9F"))
                    if let link = item.url.flatMap({ URL(string: $0) }) {
                        Link(destination: link) {
                            Text(item.title).font(.urbanist(15, .semibold)).foregroundStyle(Color(hex: "#F5F5F5")).multilineTextAlignment(.leading)
                        }
                    } else {
                        Text(item.title).font(.urbanist(15, .semibold))
                    }
                }
                .padding(.bottom, 10)
            }
        }
        .card(Color(hex: "#111111"), padding: 22)
    }
}

struct ShieldCard: View {
    @Environment(AppModel.self) var model
    let content: F1RoomContent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Spoiler shield").font(.urbanist(18, .bold))
                Spacer()
                Text(content.shieldUp ? "on until you watch" : "watched")
                    .font(.urbanist(12))
                    .foregroundStyle(Color(hex: "#9B9B9F"))
            }
            if content.shieldWeekendName == nil {
                Text("Nothing to hide yet. It goes up when qualifying starts.")
                    .font(.urbanist(13))
                    .foregroundStyle(Palette.sportsSecondary)
            } else if content.shieldUp {
                Text("\(content.shieldWeekendName ?? "Last GP") result hidden")
                    .font(.titillium(22, .bold))
                Text("Hidden across Lobby: results, standings, widgets, notifications and \(headlines) in the news wire.")
                    .font(.urbanist(13))
                    .foregroundStyle(Palette.sportsSecondary)
                Button { model.markWatched() } label: {
                    Text("I've watched it")
                        .font(.urbanist(14, .bold))
                        .foregroundStyle(Color(hex: "#0E0E0E"))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Color(hex: "#F5F5F5"), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                DividedRow(label: "P1", value: winner, verticalPadding: 6)
                DividedRow(label: "Your team", value: teamResult, verticalPadding: 6)
                Text("Standings and headlines are back.")
                    .font(.urbanist(13))
                    .foregroundStyle(Palette.sportsSecondary)
                Button { model.hideAgain() } label: {
                    Text("Hide again")
                        .font(.urbanist(13, .semibold))
                        .foregroundStyle(Color(hex: "#F5F5F5"))
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .overlay(Capsule().strokeBorder(Color(hex: "#3A3A3A"), lineWidth: 1.5))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: "#111111"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color(hex: "#3A3A3A"), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        )
    }

    private var headlines: String {
        content.hiddenHeadlines == 1 ? "1 headline" : "\(content.hiddenHeadlines) headlines"
    }

    private var winner: String {
        model.snapshot.f1LatestTopThree?.first ?? "[Winner]"
    }

    private var teamResult: String {
        guard let top = model.snapshot.f1LatestTopThree else { return "P[n] and P[n]" }
        let places = model.team.drivers.compactMap { driver in top.firstIndex(of: driver).map { "P\($0 + 1)" } }
        return places.isEmpty ? "Outside the top three" : places.joined(separator: " and ")
    }
}

struct PicksCard: View {
    @Environment(AppModel.self) var model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your qualifying picks").font(.urbanist(18, .bold))
                Spacer()
                Text(locked ? "locked" : "locks at Q1").font(.urbanist(12)).foregroundStyle(Color(hex: "#9B9B9F"))
            }
            .padding(.bottom, 4)
            if let weekend = model.currentWeekend {
                let picks = model.picks(for: weekend)
                ForEach(0..<3, id: \.self) { slot in
                    VStack(spacing: 0) {
                        Rectangle().fill(Color(hex: "#222222")).frame(height: 1)
                        HStack {
                            Text("P\(slot + 1)").font(.urbanist(15)).foregroundStyle(Palette.sportsSecondary)
                            Spacer()
                            if locked {
                                Text(picks.picks[slot].isEmpty ? "No pick" : picks.picks[slot]).font(.titillium(16, .bold))
                            } else {
                                Menu {
                                    ForEach(model.allDrivers, id: \.self) { driver in
                                        Button(driver) { model.setPick(driver, slot: slot, for: weekend) }
                                    }
                                } label: {
                                    Text(picks.picks[slot].isEmpty ? "Pick a driver" : picks.picks[slot])
                                        .font(.titillium(16, .bold))
                                        .foregroundStyle(Color(hex: "#F5F5F5"))
                                }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                                .fixedSize()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            } else {
                Text("Picks open with the first race weekend.")
                    .font(.urbanist(13))
                    .foregroundStyle(Palette.sportsSecondary)
            }
            Text("Season score [n] pts · scored once the spoiler shield comes down")
                .font(.urbanist(13))
                .foregroundStyle(Color(hex: "#9B9B9F"))
                .padding(.top, 2)
        }
        .card(Color(hex: "#111111"), padding: 22)
    }

    private var locked: Bool {
        guard let weekend = model.currentWeekend else { return true }
        return QualifyingPicks.isLocked(weekend, at: model.now)
    }
}

// MARK: - AFL

struct AFLRoom: View {
    @Environment(AppModel.self) var model

    var body: some View {
        let club = model.club
        let clubColor = Color(hex: club.colorHex)
        let status = model.snapshot.aflStatus
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("Your club").font(.urbanist(14)).foregroundStyle(Palette.sportsSecondary)
                Menu {
                    ForEach(AFLClub.all) { option in
                        Button(option.name) { model.selectClub(option.id) }
                    }
                } label: {
                    Text(club.name).font(.urbanist(14, .semibold)).foregroundStyle(Color(hex: "#F5F5F5"))
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .fixedSize()
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Color(hex: "#141414"), in: Capsule())
                .overlay(Capsule().strokeBorder(clubColor, lineWidth: 1.5))
                Text("Club colours approximate" + (model.snapshot.isSample ? " · sample data" : ""))
                    .font(.urbanist(13))
                    .foregroundStyle(Color(hex: "#9B9B9F"))
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Text("AFL")
                            .font(.urbanist(14, .heavy))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(clubColor, in: Capsule())
                        Text("\(club.name) · \(status.phaseLabel)".uppercased())
                            .font(.urbanist(14, .bold))
                            .tracking(1.7)
                            .foregroundStyle(Palette.sportsSecondary)
                    }
                    Spacer(minLength: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(status.heroKicker).font(.urbanist(14)).foregroundStyle(Color(hex: "#9B9B9F"))
                        Text(status.heroTitle).font(.urbanist(64, .heavy)).tracking(-1.9).lineLimit(1).minimumScaleFactor(0.5)
                        Text(status.heroSub).font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity, minHeight: 340, maxHeight: .infinity, alignment: .topLeading)
                .background(alignment: .bottomLeading) {
                    Text(club.nickname.uppercased())
                        .font(.urbanist(170, .heavy))
                        .tracking(-6.8)
                        .foregroundStyle(Color(hex: "#161616"))
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: 10, y: 40)
                        .accessibilityHidden(true)
                }
                .background(alignment: .topTrailing) { Glow(color: clubColor).offset(x: 120, y: -180) }
                .background(Color(hex: "#111111"))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(clubColor).frame(height: 6)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your club").font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
                        Text(club.name).font(.urbanist(30, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    ForEach(status.clubRows, id: \.self) { row in
                        HStack {
                            Text(row.label).foregroundStyle(Palette.sportsSecondary)
                            Spacer()
                            Text(row.value).font(.urbanist(15, .bold))
                        }
                    }
                    Spacer(minLength: 12)
                    Text(status.clubNote).font(.urbanist(13)).foregroundStyle(Color(hex: "#9B9B9F"))
                }
                .card(Color(hex: "#111111"))
                .frame(width: 330)
            }
            .fixedSize(horizontal: false, vertical: true)

            NewsWireCard(items: NewsItem.ordered(model.snapshot.aflNews, favouriteTag: String(club.id)))

            HStack(alignment: .center, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Beat the models").font(.urbanist(18, .bold))
                    Text("Tip each round. Lobby scores you against Squiggle's computer tipsters.")
                        .font(.urbanist(14))
                        .foregroundStyle(Color(hex: "#CFE9EE"))
                    Text(status.tipping.note).font(.urbanist(12)).foregroundStyle(Color(hex: "#CFE9EE")).padding(.top, 10)
                }
                Spacer(minLength: 20)
                TipStat(value: status.tipping.yourTips, label: "your tips", color: .white)
                TipStat(value: status.tipping.bestModel, label: "best model", color: .white)
                TipStat(value: status.tipping.yourRank, label: "your rank", color: clubColor)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "#111111"))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(clubColor.opacity(0.28)))
            )
        }
    }
}

struct TipStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.urbanist(32, .heavy)).foregroundStyle(color)
            Text(label).font(.urbanist(12)).foregroundStyle(Color(hex: "#CFE9EE"))
        }
    }
}
