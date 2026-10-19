import Foundation
import LobbyCore

/// Keeps captures on this Mac until the cloud can carry them to Notion.
/// One small JSON file in Application Support.
struct CaptureStore {
    private let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lobby", isDirectory: true).appendingPathComponent("captures.json")
    }()

    func load() -> [Capture] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? Self.decoder.decode([Capture].self, from: data)) ?? []
    }

    func save(_ captures: [Capture]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(captures).write(to: url, options: .atomic)
        } catch {
            NSLog("Lobby couldn't save captures: \(error.localizedDescription)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
