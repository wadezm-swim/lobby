import Foundation

/// A tiny launch diary in Application Support. The CI launch check reads it to
/// know the window really appeared; it's also handy when something hangs.
enum LaunchLog {
    static let url: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lobby", isDirectory: true).appendingPathComponent("launch.log")
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func note(_ text: String, fresh: Bool = false) {
        NSLog("Lobby: \(text)")
        let line = "\(formatter.string(from: Date())) \(text)\n"
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fresh || !FileManager.default.fileExists(atPath: url.path) {
                try line.write(to: url, atomically: true, encoding: .utf8)
            } else if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            }
        } catch {
            // The diary is a nicety; never let it get in the way.
        }
    }
}
