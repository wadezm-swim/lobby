import SwiftUI

/// Shown once Firebase is configured and nobody is signed in. The email and
/// password are the ones added under Authentication in the Firebase console.
struct SignInView: View {
    @Environment(\.palette) var palette
    let cloud: CloudService
    let notNow: () -> Void
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("L")
                .font(.urbanist(20, .heavy))
                .foregroundStyle(palette.lime)
                .frame(width: 48, height: 48)
                .background(Color(hex: "#0E0E0E"), in: Circle())
            Text("Sign in to the cloud").font(.urbanist(28, .bold)).tracking(-0.5)
            Text("The email and password you added under Authentication in the Firebase console. Once.")
                .font(.urbanist(14))
                .foregroundStyle(palette.muted)

            TextField("Email", text: $email)
                .textContentType(.username)
                .focused($focus, equals: .email)
                .onSubmit { focus = .password }
            SecureField("Password", text: $password)
                .textContentType(.password)
                .focused($focus, equals: .password)
                .onSubmit(submit)

            if let error = cloud.signInError {
                Text(error).font(.urbanist(13, .semibold)).foregroundStyle(Color(hex: "#C2410C"))
            }

            HStack {
                Button("Not now", action: notNow)
                    .buttonStyle(.plain)
                    .font(.urbanist(14, .semibold))
                    .foregroundStyle(palette.muted)
                Spacer()
                Button(action: submit) {
                    Text(cloud.isSigningIn ? "Signing in" : "Sign in")
                        .font(.urbanist(14, .bold))
                        .foregroundStyle(palette.onLime)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(palette.lime, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(cloud.isSigningIn || email.isEmpty || password.isEmpty)
            }
        }
        .textFieldStyle(.roundedBorder)
        .font(.urbanist(15))
        .padding(28)
        .frame(width: 420)
        .background(palette.card)
        .onAppear { focus = .email }
    }

    private func submit() {
        guard !email.isEmpty, !password.isEmpty else { return }
        cloud.signIn(email: email, password: password)
    }
}
