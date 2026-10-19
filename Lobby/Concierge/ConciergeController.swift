import AppKit
import LobbyCore
import Observation
import SwiftUI

/// What the concierge panel is showing.
@MainActor
@Observable
final class ConciergeState {
    enum Phase: Equatable {
        case options
        case results([SearchHit])
        case done(String)
    }

    var text = ""
    var selected = 0
    var phase: Phase = .options
    /// Bumped each time the panel opens so the field takes focus again.
    var openCount = 0

    func reset() {
        text = ""
        selected = 0
        phase = .options
        openCount += 1
    }
}

/// A borderless panel that can take typing without bringing the whole app forward.
final class ConciergePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Opens and closes the Option+Space concierge, and handles its keys:
/// up and down to choose, Return to do it, Command-1 to 3 as shortcuts, Esc to close.
@MainActor
final class ConciergeController: NSObject, NSWindowDelegate {
    static let shared = ConciergeController()

    let state = ConciergeState()
    private var panel: ConciergePanel?
    private var keyMonitor: Any?

    private var model: AppModel { AppModel.shared }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        state.reset()

        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + frame.height * 0.62 - size.height / 2))
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        installKeyMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: Actions

    var options: [ConciergeOption] { model.conciergeOptions(for: state.text) }

    func perform(at index: Int) {
        let options = self.options
        guard options.indices.contains(index) else { return }
        let option = options[index]
        if option.action == .search {
            let term = CaptureParser.parse(state.text, now: model.now, clock: model.clock).searchTerm
            state.selected = 0
            state.phase = .results(model.search(term))
            return
        }
        let message = model.perform(option.action, text: state.text)
        state.phase = .done(message)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self else { return }
            if case .done = self.state.phase { self.hide() }
        }
    }

    func open(_ hit: SearchHit) {
        model.room = hit.room
        hide()
        model.openMainWindow?()
        NSApp.activate()
    }

    // MARK: Building

    private func makePanel() -> ConciergePanel {
        let panel = ConciergePanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: ConciergeView(controller: self).environment(model))
        return panel
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true else { return event }
            return self.handle(event) ? nil : event
        }
    }

    /// True when the key was ours.
    private func handle(_ event: NSEvent) -> Bool {
        let count: Int
        switch state.phase {
        case .options: count = options.count
        case .results(let hits): count = hits.count
        case .done: count = 0
        }

        switch Int(event.keyCode) {
        case 53: // Esc: back out of results, else close
            if case .results = state.phase { state.phase = .options } else { hide() }
            return true
        case 125: // Down
            if count > 0 { state.selected = min(count - 1, state.selected + 1) }
            return true
        case 126: // Up
            state.selected = max(0, state.selected - 1)
            return true
        case 36, 76: // Return
            switch state.phase {
            case .options: perform(at: state.selected)
            case .results(let hits): if hits.indices.contains(state.selected) { open(hits[state.selected]) }
            case .done: hide()
            }
            return true
        case 18, 19, 20: // Command-1, 2, 3
            guard event.modifierFlags.contains(.command) else { return false }
            if case .options = state.phase { perform(at: Int(event.keyCode) - 17) }
            return true
        default:
            return false
        }
    }
}
