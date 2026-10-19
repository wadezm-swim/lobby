import SwiftUI
import LobbyCore

/// Option+Space: type anything, then choose what Lobby does with it.
struct ConciergeView: View {
    let controller: ConciergeController
    @FocusState private var fieldFocused: Bool

    private var state: ConciergeState { controller.state }
    private let lime = Color(hex: "#D4FF3F")
    private let grey = Color(hex: "#9B9B9F")

    var body: some View {
        @Bindable var state = controller.state
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text("L")
                    .font(.urbanist(16, .heavy))
                    .foregroundStyle(Color(hex: "#0E0E0E"))
                    .frame(width: 36, height: 36)
                    .background(lime, in: Circle())
                    .accessibilityHidden(true)
                TextField("", text: $state.text, prompt: Text("Ask or capture").foregroundStyle(Color(hex: "#6E6E73")))
                    .textFieldStyle(.plain)
                    .font(.urbanist(19, .medium))
                    .foregroundStyle(Color(hex: "#F5F5F5"))
                    .focused($fieldFocused)
                    .accessibilityLabel("Ask or capture")
                    .onChange(of: state.text) {
                        state.selected = 0
                        state.phase = .options
                    }
                Text("esc")
                    .font(.urbanist(12))
                    .foregroundStyle(grey)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#1F1F1F"), in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)

            Group {
                switch state.phase {
                case .options:
                    options
                case .results(let hits):
                    results(hits)
                case .done(let message):
                    Text(message)
                        .font(.urbanist(16, .semibold))
                        .foregroundStyle(Color(hex: "#F5F5F5"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            HStack {
                Text("Option+Space from anywhere on your Mac")
                Spacer()
                Text("↑↓ choose · ↵ do it")
            }
            .font(.urbanist(12))
            .foregroundStyle(grey)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 640, height: 400)
        .background(Color(hex: "#0E0E0E"), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
        .onAppear { fieldFocused = true }
        .onChange(of: state.openCount) { fieldFocused = true }
    }

    @ViewBuilder
    private var options: some View {
        let items = controller.options
        if items.isEmpty {
            Text("Capture a task, set a reminder, search, or add something you're waiting on. Try \"chase officials roster thursday\".")
                .font(.urbanist(14))
                .foregroundStyle(grey)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        VStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, option in
                let on = index == state.selected
                Button { controller.perform(at: index) } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.urbanist(15, .bold))
                                .foregroundStyle(on ? Color(hex: "#0E0E0E") : Color(hex: "#F5F5F5"))
                                .lineLimit(1)
                            Text(option.detail)
                                .font(.urbanist(13))
                                .foregroundStyle(on ? Color(hex: "#2A2A2A") : grey)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Text(option.key)
                            .font(.urbanist(12, .bold))
                            .foregroundStyle(on ? Color(hex: "#0E0E0E") : grey)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .background(on ? lime : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .onHover { hovering in if hovering { state.selected = index } }
            }
        }
    }

    @ViewBuilder
    private func results(_ hits: [SearchHit]) -> some View {
        if hits.isEmpty {
            Text("Nothing in Lobby matches that yet. Notion search comes with the cloud.")
                .font(.urbanist(14))
                .foregroundStyle(grey)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                    let on = index == state.selected
                    Button { controller.open(hit) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.title).font(.urbanist(15, .bold))
                                .foregroundStyle(on ? Color(hex: "#0E0E0E") : Color(hex: "#F5F5F5"))
                            Text(hit.detail).font(.urbanist(13))
                                .foregroundStyle(on ? Color(hex: "#2A2A2A") : grey)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(on ? lime : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 260)
    }
}
