import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import LobbyCore
import Observation

/// Lobby's link to Firebase. Configures from a GoogleService-Info.plist in
/// Application Support (so it never ships inside the app or the repo), signs
/// in with email and password, listens to the documents the cloud writes and
/// hands captures up.
///
/// With no plist, nothing here runs and the app stays on sample data.
@MainActor
@Observable
final class CloudService {
    enum State: Equatable {
        case noConfig
        case signedOut
        case signedIn(uid: String)
    }

    private(set) var state: State = .noConfig
    private(set) var signInError: String?
    private(set) var isSigningIn = false

    @ObservationIgnored private var listeners: [ListenerRegistration] = []
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored private weak var model: AppModel?

    static let configURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lobby", isDirectory: true).appendingPathComponent("GoogleService-Info.plist")
    }()

    var isConfigured: Bool { state != .noConfig }

    var needsSignIn: Bool { state == .signedOut }

    var uid: String? {
        if case .signedIn(let uid) = state { return uid }
        return nil
    }

    /// Call once at launch, before anything else touches Firebase.
    func configure(model: AppModel) {
        self.model = model
        guard FileManager.default.fileExists(atPath: Self.configURL.path),
              let options = FirebaseOptions(contentsOfFile: Self.configURL.path) else {
            state = .noConfig
            return
        }
        FirebaseApp.configure(options: options)
        state = .signedOut
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.authChanged(user) }
        }
    }

    private func authChanged(_ user: User?) {
        if let user {
            state = .signedIn(uid: user.uid)
            listen()
            uploadQueuedCaptures()
        } else {
            state = .signedOut
            stopListening()
        }
    }

    func signIn(email: String, password: String) {
        guard !isSigningIn else { return }
        isSigningIn = true
        signInError = nil
        Task {
            do {
                try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
            } catch {
                signInError = Self.plainWords(for: error)
            }
            isSigningIn = false
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    /// Firebase's error text is for developers. These are for Wade.
    static func plainWords(for error: Error) -> String {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else { return "Couldn't sign in. Try again in a minute." }
        switch code {
        case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail:
            return "That email and password don't match what's in Firebase."
        case .networkError:
            return "No connection. Lobby keeps running on what it has."
        case .tooManyRequests:
            return "Too many tries. Give it a few minutes."
        case .userDisabled:
            return "That account is switched off in Firebase."
        default:
            return "Couldn't sign in. Try again in a minute."
        }
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

    /// Sends every capture still waiting on the Mac. The cloud files it in Notion.
    func uploadQueuedCaptures() {
        guard let uid, let model else { return }
        let db = Firestore.firestore()
        let formatter = ISO8601DateFormatter()
        for capture in model.captures where capture.status == .queued {
            var fields: [String: Any] = [
                "text": capture.text,
                "title": capture.title,
                "kind": capture.kind.rawValue,
                "createdAt": formatter.string(from: capture.createdAt),
                "status": "queued",
            ]
            if let due = capture.due { fields["due"] = formatter.string(from: due) }
            if let projectID = capture.projectID { fields["projectID"] = projectID }
            db.document("users/\(uid)/captures/\(capture.id)").setData(fields) { [weak self] error in
                Task { @MainActor in
                    if let error {
                        NSLog("Lobby: capture didn't upload: \(error.localizedDescription)")
                    } else {
                        self?.model?.markCaptureSent(capture.id)
                    }
                }
            }
        }
    }
}
