import Foundation
import Observation
import LobbyCore

/// What the cloud has sent so far. Laid over the sample snapshot so the rest
/// stays sample until its own feed arrives.
struct LiveSports {
    var f1Calendar: F1Calendar?
    var f1Standings: [DriverStanding]?
    var f1TopThreeKnown = false
    var f1TopThree: [String]?
    var f1News: [NewsItem]?
    var aflNews: [NewsItem]?
    var afl: Cloud.AFLDoc?

    var isEmpty: Bool {
        f1Calendar == nil && f1Standings == nil && !f1TopThreeKnown && f1News == nil && aflNews == nil && afl == nil
    }
}

/// One search hit for the concierge.
struct SearchHit: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let room: Room
}

/// What the concierge can do with what he typed.
struct ConciergeOption: Identifiable, Hashable {
    enum Action: Hashable {
        case task, reminder, search, waitingOn
    }

    var id: Action { action }
    let action: Action
    let title: String
    let detail: String
    let key: String
}

/// Everything the app shows and remembers. Sample data for now; each card
/// switches to the cloud one at a time.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let clock = LobbyClock.adelaide
    let sun = Sun.adelaide
    let workHours = WorkHours.standard

    private(set) var now = Date()
    private(set) var snapshot: LobbySnapshot
    var room: Room = .home

    private(set) var f1TeamID: String
    private(set) var aflClubID: Int
    private(set) var modeState: ModeState
    private(set) var shield: SpoilerShield
    private(set) var quizLog: QuizLog
    private(set) var picks: [String: QualifyingPicks]
    private(set) var captures: [Capture]
    /// Sample data only: flip the F1 room between race week and off-season.
    var f1PreviewPhase: F1Phase?
    var sport: Sport = .f1

    /// The quiz question just answered, held on screen until "Next".
    private(set) var quizFeedback: (index: Int, picked: String)?
    /// A short confirmation, like "Saved for your Notion inbox".
    private(set) var toast: String?
    var hotKeyRegistered = true
    /// The link to Firebase. Does nothing until the config file exists.
    let cloud = CloudService()
    var signInDismissed = false
    @ObservationIgnored private var live = LiveSports()
    /// Set by the main window so the concierge and menu bar can bring it back.
    @ObservationIgnored var openMainWindow: (() -> Void)?

    enum Sport: String, Hashable {
        case f1, afl
    }

    private let defaults = UserDefaults.standard
    private let captureStore = CaptureStore()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var snapshotDay: String

    private init() {
        let start = Date()
        let defaults = UserDefaults.standard
        let teamID = defaults.string(forKey: Keys.team) ?? F1Team.mclaren.id
        f1TeamID = teamID
        let savedClub = defaults.integer(forKey: Keys.club)
        aflClubID = savedClub == 0 ? AFLClub.portAdelaide.id : savedClub
        modeState = AppModel.load(Keys.mode, from: defaults) ?? ModeState()
        shield = AppModel.load(Keys.shield, from: defaults) ?? SpoilerShield()
        quizLog = AppModel.load(Keys.quiz, from: defaults) ?? QuizLog()
        picks = AppModel.load(Keys.picks, from: defaults) ?? [:]
        captures = CaptureStore().load()
        snapshot = SampleData.snapshot(now: start, clock: .adelaide, f1TeamID: teamID)
        snapshotDay = LobbyClock.adelaide.dayKey(start)
        now = start
    }

    /// Ticks every 15 seconds so countdowns, next up and day/night stay current.
    func start() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.tick()
            }
        }
    }

    private func tick() {
        now = Date()
        let today = clock.dayKey(now)
        if today != snapshotDay && snapshot.isSample {
            snapshot = SampleData.snapshot(now: now, clock: clock, f1TeamID: f1TeamID)
            overlayLive()
            snapshotDay = today
            quizFeedback = nil
            quizLog.prune(keepingDaysFrom: now, clock: clock)
            save(quizLog, Keys.quiz)
        }
    }

    // MARK: - Derived

    var mode: DayMode { modeState.mode(at: now, hours: workHours, clock: clock) }
    var isNight: Bool { sun.isNight(at: now) }
    var team: F1Team { F1Team.team(id: f1TeamID) ?? .mclaren }
    var club: AFLClub { AFLClub.club(id: aflClubID) ?? .portAdelaide }
    /// Live from Squiggle when the cloud has it, else the sample.
    var aflStatus: AFLStatus { live.afl?.status(for: club, now: now, clock: clock) ?? snapshot.aflStatus }
    var nextMeeting: Meeting? { Meeting.nextUp(in: snapshot.meetings, at: now) }
    var todaysMeetings: [Meeting] { snapshot.meetings(on: now, clock: clock) }
    var nextTrip: Trip? { snapshot.nextTrip(after: now) }
    var greeting: String { Greeting.text(at: now, name: snapshot.ownerName, clock: clock) }

    var dateLine: String {
        clock.longDate(now) + (snapshot.isSample ? " · sample data" : "")
    }

    var f1: F1RoomContent {
        F1RoomContent.make(snapshot: snapshot, team: team, shield: shield, now: now, clock: clock, previewPhase: f1PreviewPhase)
    }

    var currentWeekend: F1Weekend? { snapshot.f1Calendar.current(at: now) }
    var shieldWeekend: F1Weekend? { shield.weekend(in: snapshot.f1Calendar, at: now) }
    var shieldUp: Bool { shield.isUp(in: snapshot.f1Calendar, at: now) }

    var lookingForward: String? {
        var things: [LookingForward.Thing] = snapshot.trips.map { .init(title: $0.name, date: $0.departs, isMajor: true) }
        if let weekend = currentWeekend, let race = weekend.race {
            things.append(.init(title: weekend.shortName, date: race.start, isMajor: false))
        }
        return LookingForward.pick(things, at: now).map { LookingForward.phrase($0, at: now, clock: clock) }
    }

    /// What sits next to the Lobby icon in the menu bar.
    var menuBarTitle: String {
        if let reminder = dueReminder { return "Reminder: \(reminder.title)" }
        if let meeting = nextMeeting, clock.startOfDay(meeting.start) == clock.startOfDay(now) {
            return "\(clock.clock(meeting.start)) \(meeting.title)"
        }
        if let weekend = currentWeekend, let session = weekend.nextSession(after: now) {
            return "\(weekend.shortName) \(Countdown.short(from: now, to: session.start))"
        }
        return "Lobby"
    }

    /// A reminder whose time came up in the last two hours.
    var dueReminder: Capture? {
        captures.first { capture in
            guard capture.kind == .reminder, let due = capture.due else { return false }
            return due <= now && now.timeIntervalSince(due) < 2 * 3600
        }
    }

    var queuedCaptureCount: Int { captures.filter { $0.status == .queued }.count }

    // MARK: - Mode

    func setMode(_ mode: DayMode) {
        modeState.choose(mode, at: now, hours: workHours, clock: clock)
        save(modeState, Keys.mode)
    }

    // MARK: - Work

    func toggleTask(_ id: String) {
        guard let index = snapshot.topThree.firstIndex(where: { $0.id == id }) else { return }
        snapshot.topThree[index].done.toggle()
    }

    /// Swaps the first unticked item for the next one in the backlog.
    func swapOne() {
        guard let index = snapshot.topThree.firstIndex(where: { !$0.done }),
              !snapshot.topThreeBacklog.isEmpty else {
            showToast("Nothing left to swap in.")
            return
        }
        let incoming = snapshot.topThreeBacklog.removeFirst()
        snapshot.topThreeBacklog.append(snapshot.topThree[index])
        snapshot.topThree[index] = incoming
    }

    func nudge(_ id: String) {
        guard let index = snapshot.waitingOn.firstIndex(where: { $0.id == id }) else { return }
        snapshot.waitingOn[index].nudgedAt = now
        let what = snapshot.waitingOn[index].what
        record(Capture(text: "Nudge: \(what)", title: "Nudge about \(what)", kind: .task, createdAt: now))
        showToast("Nudge noted. It'll sit in your Notion inbox.")
    }

    // MARK: - Captures and the concierge

    func conciergeOptions(for text: String) -> [ConciergeOption] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let parsed = CaptureParser.parse(trimmed, now: now, clock: clock)
        let project = ProjectMatcher.match(trimmed, in: snapshot.projects)
        let hits = search(parsed.searchTerm).count

        var taskDetail = ["Notion inbox"]
        if let project { taskDetail.append(project.name) }
        if let due = parsed.due { taskDetail.append("due \(clock.shortDate(due))") }

        let reminderDay = parsed.due.map { clock.calendarDays(from: now, to: $0) == 0 ? "Today" : clock.weekdayName($0) } ?? "Tomorrow"
        let reminderAt = reminderTime(for: parsed.due)
        let byWhen = parsed.due.map { "by \(clock.weekdayName($0))" } ?? "in three days"

        return [
            ConciergeOption(action: .task, title: "Task: \(parsed.title)", detail: taskDetail.joined(separator: " · "), key: "↵"),
            ConciergeOption(action: .reminder, title: "Reminder only", detail: "\(reminderDay) \(clock.clockWithSuffix(reminderAt)), menu bar nudge", key: "⌘1"),
            ConciergeOption(action: .search, title: "Search \"\(parsed.searchTerm)\"", detail: hits == 1 ? "1 match in Lobby" : "\(hits) matches in Lobby", key: "⌘2"),
            ConciergeOption(action: .waitingOn, title: "Add to Waiting on", detail: "Flags it if nothing back \(byWhen)", key: "⌘3"),
        ]
    }

    /// Does the option and returns what to say about it.
    @discardableResult
    func perform(_ action: ConciergeOption.Action, text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let parsed = CaptureParser.parse(trimmed, now: now, clock: clock)
        let project = ProjectMatcher.match(trimmed, in: snapshot.projects)

        switch action {
        case .task:
            record(Capture(text: trimmed, title: parsed.title, kind: .task, createdAt: now, due: parsed.due, projectID: project?.id))
            return "Saved. It goes to your Notion inbox once the cloud is on."
        case .reminder:
            let at = reminderTime(for: parsed.due)
            record(Capture(text: trimmed, title: parsed.title, kind: .reminder, createdAt: now, due: at))
            return "Reminder set for \(clock.dayAndTime(at))."
        case .waitingOn:
            let flagAfter = parsed.due ?? clock.addingDays(3, to: clock.startOfDay(now))
            snapshot.waitingOn.append(WaitingOn(
                id: UUID().uuidString,
                initials: Self.initials(for: parsed.searchTerm),
                what: parsed.title,
                since: now,
                tint: .lilac,
                flagAfter: flagAfter
            ))
            record(Capture(text: trimmed, title: parsed.title, kind: .waitingOn, createdAt: now, due: flagAfter, projectID: project?.id))
            return "Added to Waiting on."
        case .search:
            return ""
        }
    }

    /// Quick capture from the menu bar or the Work room: always a task.
    func quickCapture(_ text: String) {
        let message = perform(.task, text: text)
        if !message.isEmpty { showToast(message) }
    }

    func search(_ term: String) -> [SearchHit] {
        let needle = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard needle.count >= 2 else { return [] }
        func matches(_ text: String) -> Bool { text.lowercased().contains(needle) }

        var hits: [SearchHit] = []
        hits += snapshot.meetings.filter { matches($0.title) }.map {
            SearchHit(title: $0.title, detail: "Meeting · \(clock.dayAndTime($0.start))", room: .work)
        }
        hits += snapshot.topThree.filter { matches($0.title) }.map {
            SearchHit(title: $0.title, detail: "Top three", room: .work)
        }
        hits += snapshot.projects.filter { matches($0.name) || matches($0.nextStep) }.map {
            SearchHit(title: $0.name, detail: "Project · next: \($0.nextStep)", room: .work)
        }
        hits += snapshot.waitingOn.filter { matches($0.what) }.map {
            SearchHit(title: $0.what, detail: "Waiting on", room: .work)
        }
        hits += captures.filter { matches($0.text) }.map {
            SearchHit(title: $0.title, detail: "Capture · \(clock.shortDate($0.createdAt))", room: .work)
        }
        return hits
    }

    private func reminderTime(for due: Date?) -> Date {
        let day = due ?? clock.addingDays(1, to: now)
        let nineAM = clock.date(on: day, hour: 9)
        // Asked for "today" after 9am: nudge in an hour instead.
        return nineAM > now ? nineAM : now.addingTimeInterval(3600)
    }

    private func record(_ capture: Capture) {
        captures.append(capture)
        captureStore.save(captures)
        cloud.uploadQueuedCaptures()
    }

    func markCaptureSent(_ id: String) {
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return }
        captures[index].status = .sent
        captureStore.save(captures)
    }

    static func initials(for text: String) -> String {
        let letters = text.split(separator: " ").prefix(2).compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    // MARK: - Sports

    func selectTeam(_ id: String) {
        f1TeamID = id
        defaults.set(id, forKey: Keys.team)
        // The sample's F1 news names the team; live news is tagged instead.
        if snapshot.isSample && !snapshot.sportsLive {
            let topThree = snapshot.topThree
            snapshot = SampleData.snapshot(now: now, clock: clock, f1TeamID: id)
            snapshot.topThree = topThree
            overlayLive()
        }
    }

    // MARK: - Live data from the cloud

    func applyLive(f1Calendar: F1Calendar) { live.f1Calendar = f1Calendar; overlayLive() }
    func applyLive(f1Standings: [DriverStanding]) { live.f1Standings = f1Standings; overlayLive() }
    func applyLive(f1TopThree: [String]?) { live.f1TopThreeKnown = true; live.f1TopThree = f1TopThree; overlayLive() }
    func applyLive(f1News: [NewsItem]) { live.f1News = f1News; overlayLive() }
    func applyLive(aflNews: [NewsItem]) { live.aflNews = aflNews; overlayLive() }
    func applyLive(afl: Cloud.AFLDoc) { live.afl = afl; overlayLive() }

    private func overlayLive() {
        if let calendar = live.f1Calendar { snapshot.f1Calendar = calendar }
        if let standings = live.f1Standings { snapshot.f1Standings = standings }
        if live.f1TopThreeKnown { snapshot.f1LatestTopThree = live.f1TopThree }
        if let news = live.f1News { snapshot.f1News = news }
        if let news = live.aflNews { snapshot.aflNews = news }
        snapshot.sportsLive = !live.isEmpty
    }

    func selectClub(_ id: Int) {
        aflClubID = id
        defaults.set(id, forKey: Keys.club)
    }

    func markWatched() {
        guard let weekend = shieldWeekend else { return }
        shield.markWatched(weekend, at: now)
        save(shield, Keys.shield)
    }

    func hideAgain() {
        guard let weekend = shieldWeekend else { return }
        shield.hideAgain(weekend)
        save(shield, Keys.shield)
    }

    func picks(for weekend: F1Weekend) -> QualifyingPicks {
        picks[weekend.id] ?? QualifyingPicks(weekendID: weekend.id)
    }

    func setPick(_ driver: String, slot: Int, for weekend: F1Weekend) {
        guard !QualifyingPicks.isLocked(weekend, at: now), (0..<3).contains(slot) else { return }
        var current = picks(for: weekend)
        // A driver can only be in one slot.
        for index in current.picks.indices where current.picks[index] == driver { current.picks[index] = "" }
        current.picks[slot] = driver
        picks[weekend.id] = current
        save(picks, Keys.picks)
    }

    var allDrivers: [String] {
        F1Team.all.flatMap(\.drivers).sorted()
    }

    // MARK: - Daily three

    var quizToday: [QuizQuestion] { snapshot.quizBank.daily(for: clock.dayKey(now)) }
    var quizAnswers: [Bool] { quizLog.answers(on: clock.dayKey(now)) }
    var quizStreak: Int { quizLog.streak(at: now, clock: clock) }

    /// The question on screen: the one just answered (until Next), else the next unanswered.
    var quizIndex: Int { quizFeedback?.index ?? quizAnswers.count }

    func answerQuiz(_ option: String) {
        let index = quizAnswers.count
        guard quizFeedback == nil, index < quizToday.count else { return }
        quizLog.record(correct: option == quizToday[index].answer, on: clock.dayKey(now))
        save(quizLog, Keys.quiz)
        quizFeedback = (index, option)
    }

    func nextQuizQuestion() {
        quizFeedback = nil
    }

    // MARK: - Saving

    private enum Keys {
        static let team = "f1TeamID"
        static let club = "aflClubID"
        static let mode = "modeState"
        static let shield = "spoilerShield"
        static let quiz = "quizLog"
        static let picks = "qualifyingPicks"
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
