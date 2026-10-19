import SwiftUI
import LobbyCore

/// The main window: rooms down the left, the chosen room on the right.
/// Light by day, dark at night; the Sports room is always dark.
struct RootView: View {
    @Environment(AppModel.self) var model
    @Environment(\.openWindow) private var openWindow

    private var palette: Palette {
        if model.room == .sports { return .sports }
        return model.isNight ? .night : .day
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Sidebar()
            ScrollView {
                Group {
                    switch model.room {
                    case .home: HomeView()
                    case .work: WorkView()
                    case .sports: SportsView()
                    case .fleet, .trips, .brand: LaterRoomView(room: model.room)
                    }
                }
                .padding(.trailing, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
        }
        .padding(.leading, 20)
        .background(palette.canvas)
        .overlay(alignment: .bottom) { ToastView() }
        .sheet(isPresented: Binding(get: { model.cloud.needsSignIn && !model.signInDismissed }, set: { _ in })) {
            SignInView(cloud: model.cloud) {
                model.signInDismissed = true
                model.showToast("Sample data until you sign in. Quit and reopen Lobby to see this again.")
            }
            .environment(\.palette, palette)
        }
        .environment(\.palette, palette)
        .preferredColorScheme(palette.isDark ? .dark : .light)
        .font(.urbanist(15))
        .foregroundStyle(palette.ink)
        .animation(.easeInOut(duration: 0.25), value: model.room)
        .onAppear {
            NSLog("Lobby: window ready")
            let openWindow = openWindow
            model.openMainWindow = { openWindow(id: "main") }
        }
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) var model
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 10) {
            Text("L")
                .font(.urbanist(20, .heavy))
                .foregroundStyle(palette.isDark ? Color(hex: "#0E0E0E") : palette.lime)
                .frame(width: 48, height: 48)
                .background(palette.isDark ? Color.white : Color(hex: "#0E0E0E"), in: Circle())
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            ForEach(Room.allCases) { room in
                let on = model.room == room
                Button { model.room = room } label: {
                    Image(systemName: room.symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(on ? Color(hex: "#0E0E0E") : palette.muted)
                        .frame(width: 48, height: 48)
                        .background(on ? (model.room == .sports ? Color.white : palette.lime) : .clear, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(room.label)
                .accessibilityLabel(room.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.vertical, 18)
        .frame(width: 84)
        .frame(maxHeight: .infinity)
        .background(model.room == .sports ? Color(hex: "#141414") : palette.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.vertical, 20)
    }
}

/// The short confirmation that slides up after a capture.
struct ToastView: View {
    @Environment(AppModel.self) var model

    var body: some View {
        if let toast = model.toast {
            Text(toast)
                .font(.urbanist(14, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(hex: "#0E0E0E"), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
                .padding(.bottom, 28)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
