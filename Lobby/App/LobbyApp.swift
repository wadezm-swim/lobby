import AppKit
import Carbon.HIToolbox
import SwiftUI

@main
struct LobbyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    init() {
        FontRegistry.registerBundledFonts()
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
        NSLog("Lobby: finished launching")
        let model = AppModel.shared
        model.start()
        hotKey = HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey)) {
            ConciergeController.shared.toggle()
        }
        if hotKey == nil {
            model.hotKeyRegistered = false
            model.showToast("Option+Space is taken by another app. The search box on Home still opens the concierge.")
        }
    }

    /// Closing the window leaves Lobby running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
