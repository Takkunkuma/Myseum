import SwiftUI

/// Sign in / create account sheet (email + password).
struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var auth = AuthService.shared

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    enum Mode { case signIn, signUp }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    Text("Sign In").tag(Mode.signIn)
                    Text("Create Account").tag(Mode.signUp)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    if mode == .signUp {
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                    }
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
                if let infoMessage {
                    Text(infoMessage).foregroundStyle(.secondary).font(.footnote)
                }

                Section {
                    Button(action: submit) {
                        HStack {
                            Spacer()
                            if isWorking { ProgressView() }
                            else { Text(mode == .signIn ? "Sign In" : "Create Account").bold() }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || isWorking)
                }

                if GoogleConfig.isConfigured {
                    Section {
                        Button(action: signInWithGoogle) {
                            HStack {
                                Spacer()
                                Image(systemName: "globe")
                                Text("Continue with Google")
                                Spacer()
                            }
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .navigationTitle(mode == .signIn ? "Welcome back" : "Join Myseum")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: auth.isAuthenticated) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    private func signInWithGoogle() {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do { try await auth.signInWithGoogle() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private var canSubmit: Bool {
        let validBase = email.contains("@") && password.count >= 6
        return mode == .signIn ? validBase : (validBase && !username.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                if mode == .signIn {
                    try await auth.signIn(email: email, password: password)
                } else {
                    try await auth.signUp(
                        email: email,
                        password: password,
                        username: username.trimmingCharacters(in: .whitespaces)
                    )
                    // If email confirmation is on, there's no session yet.
                    if !auth.isAuthenticated {
                        infoMessage = "Check your email to confirm your account, then sign in."
                        mode = .signIn
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
