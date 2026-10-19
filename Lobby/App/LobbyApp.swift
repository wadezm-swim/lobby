import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The real entry point, so the launch diary gets a line before SwiftUI,
/// AppKit or the model do anything at all.
@main
enum LobbyMain {
    static func main() {
        LaunchLog.note("process started", fresh: true)
        LobbyApp.main()
    }
}

struct LobbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    init() {
        LaunchLog.note("app init")
        FontRegistry.registerBundledFonts()
        LaunchLog.note("fonts registered")
        // Before anything touches Firebase. Quietly does nothing without the config file.
        AppModel.shared.cloud.configure(model: AppModel.shared)
    }

    var body: some Scene {
        Window("Lobby", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1440, height: 900)
        .windowResizability(.contentMinSize)
        // Launched from Finder, a Window scene next to a MenuBarExtra doesn't
        // always present itself. Insist, and skip window restoration.
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)

        MenuBarExtra {
            GlanceView()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchLog.note("finished launching")
        let model = AppModel.shared
        model.start()
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            ConciergeController.shared.toggle()
        }
        if hotKey == nil {
            model.hotKeyRegistered = false
            model.showToast("Option+Space is taken by another app. The search box on Home still opens the concierge.")
        }
        // Belt and braces for the main window: open it if SwiftUI didn't.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            Self.openMainWindowIfMissing()
        }
    }

    /// Clicking the Dock icon with no window open brings the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Self.openMainWindowIfMissing() }
        return true
    }

    @MainActor
    static func openMainWindowIfMissing() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && !($0 is NSPanel) && $0.styleMask.contains(.titled) }
        guard !hasWindow else { return }
        LaunchLog.note("main window missing, opening it")
        AppModel.shared.openMainWindow?()
        NSApp.activate()
    }

    /// Closing the window leaves Lobby running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
