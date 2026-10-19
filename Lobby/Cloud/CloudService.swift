import FirebaseCore
import FirebaseFirestore
import Foundation
import LobbyCore
import Observation

/// Lobby's link to Firebase. Configures from a GoogleService-Info.plist in
/// Application Support (so it never ships inside the app or the repo) and
/// listens to the documents the cloud writes.
///
/// There is no sign-in yet: Firebase's sign-in on a Mac needs the kind of
/// keychain access only a properly signed app gets, which arrives with the
/// phone stage. The sports and news documents are public reads, so the Sports
/// room goes live without it. Captures wait on the Mac until then.
///
/// With no plist, nothing here runs and the app stays on sample data.
@MainActor
@Observable
final class CloudService {
    enum State: Equatable {
        case noConfig
        case live
    }

    private(set) var state: State = .noConfig

    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    @ObservationIgnored private weak var model: AppModel?

    static let configURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lobby", isDirectory: true).appendingPathComponent("GoogleService-Info.plist")
    }()

    var isConfigured: Bool { state != .noConfig }

    /// Call once at launch, before anything else touches Firebase.
    func configure(model: AppModel) {
        self.model = model
        guard FileManager.default.fileExists(atPath: Self.configURL.path),
              let options = FirebaseOptions(contentsOfFile: Self.configURL.path) else {
            state = .noConfig
            return
        }
        FirebaseApp.configure(options: options)
        state = .live
        LaunchLog.note("firebase configured")
        listen()
    }

    // MARK: - Reading

    private func listen() {
        stopListening()
        let db = Firestore.firestore()

        func watch<T: Decodable>(_ path: String, as type: T.Type, apply: @escaping @MainActor (T) -> Void) {
            let registration = db.document(path).addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else {
                    if let error { NSLog("Lobby: \(path) listener: \(error.localizedDescription)") }
                    return
                }
                do {
                    let json = try JSONSerialization.data(withJSONObject: data)
                    let value = try Cloud.decode(type, from: json)
                    Task { @MainActor in apply(value) }
                } catch {
                    NSLog("Lobby: couldn't read \(path): \(error)")
                }
            }
            listeners.append(registration)
        }

        watch("sports/f1Calendar", as: Cloud.F1CalendarDoc.self) { [weak self] doc in self?.model?.applyLive(f1Calendar: doc.calendar()) }
        watch("sports/f1Standings", as: Cloud.F1StandingsDoc.self) { [weak self] doc in self?.model?.applyLive(f1Standings: doc.standings()) }
        watch("sports/f1Latest", as: Cloud.F1LatestDoc.self) { [weak self] doc in self?.model?.applyLive(f1TopThree: doc.race?.topThree) }
        watch("news/f1", as: Cloud.NewsDoc.self) { [weak self] doc in self?.model?.applyLive(f1News: doc.news()) }
        watch("news/afl", as: Cloud.NewsDoc.self) { [weak self] doc in self?.model?.applyLive(aflNews: doc.news()) }
        watch("sports/afl", as: Cloud.AFLDoc.self) { [weak self] doc in self?.model?.applyLive(afl: doc) }
    }

    private func stopListening() {
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }

    // MARK: - Captures

    /// Captures go to Notion through the cloud once the app can sign in. Until
    /// then they stay in the Mac's queue, which this leaves alone.
    func uploadQueuedCaptures() {}
}
