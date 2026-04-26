//
//  NativeMigrationShellView.swift
//  Mes Finances iOS
//
//  Temporary shell for testing native screens alongside the WebView reference.
//

import SwiftUI

struct NativeMigrationShellView: View {
    @StateObject private var controller = NativeMigrationController()
    @AppStorage("migration_show_native_dashboard") private var showNativeDashboard = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if showNativeDashboard {
                    nativeContent
                } else {
                    #if os(iOS)
                    WebAppView()
                        .ignoresSafeArea(.container, edges: .bottom)
                    #else
                    NativeUnavailableView()
                    #endif
                }
            }

            migrationToggle
                .padding(.top, 10)
                .padding(.trailing, 12)
        }
        .task {
            controller.start()
        }
        .onDisappear {
            controller.stop()
        }
    }

    @ViewBuilder
    private var nativeContent: some View {
        switch controller.authState {
        case .unavailable:
            NativeUnavailableView()
        case .checking:
            NativeLoadingView(title: "Connexion Firebase")
        case .signedOut:
            NativeLoginView(controller: controller)
        case .signedIn:
            ZStack(alignment: .top) {
                NativeDashboardView(store: controller.store)

                if controller.isLoadingDocument {
                    NativeLoadingBanner(text: "Synchronisation Firebase...")
                        .padding(.top, 58)
                } else if let message = controller.errorMessage {
                    NativeErrorBanner(text: message)
                        .padding(.top, 58)
                }
            }
        }
    }

    private var migrationToggle: some View {
        Button {
            showNativeDashboard.toggle()
        } label: {
            Image(systemName: showNativeDashboard ? "swift" : "safari")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(showNativeDashboard ? NativeTheme.gold : NativeTheme.text)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
        }
        .accessibilityLabel(showNativeDashboard ? "Afficher la WebApp" : "Afficher le dashboard natif")
    }
}

private struct NativeLoginView: View {
    @ObservedObject var controller: NativeMigrationController
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connexion native")
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                    Text("Connecte Firebase cote Swift pour comparer le dashboard natif a la WebApp.")
                        .font(.subheadline)
                        .foregroundStyle(NativeTheme.mutedText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .nativeFieldStyle()

                    SecureField("Mot de passe", text: $password)
                        .textContentType(.password)
                        .nativeFieldStyle()
                }

                if let error = controller.errorMessage {
                    Text(error)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(NativeTheme.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        isSigningIn = true
                        await controller.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                        isSigningIn = false
                    }
                } label: {
                    HStack {
                        if isSigningIn {
                            ProgressView()
                                .tint(.black)
                        }
                        Text(isSigningIn ? "Connexion..." : "Se connecter")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.black)
                    .background(NativeTheme.gold, in: RoundedRectangle(cornerRadius: 10))
                }
                .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                .opacity(email.isEmpty || password.isEmpty ? 0.45 : 1)
            }
            .padding(22)
            .foregroundStyle(NativeTheme.text)
        }
    }
}

private struct NativeUnavailableView: View {
    var body: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(NativeTheme.gold)
                Text("Firebase natif indisponible")
                    .font(.headline)
                Text("Ouvre le projet avec Xcode et laisse Swift Package Manager resoudre Firebase pour tester ce mode.")
                    .font(.footnote)
                    .foregroundStyle(NativeTheme.mutedText)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .foregroundStyle(NativeTheme.text)
        }
    }
}

private struct NativeLoadingView: View {
    var title: String

    var body: some View {
        ZStack {
            NativeTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(NativeTheme.gold)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(NativeTheme.text)
            }
        }
    }
}

private struct NativeLoadingBanner: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(NativeTheme.gold)
            Text(text)
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .foregroundStyle(NativeTheme.text)
        .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}

private struct NativeErrorBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(NativeTheme.red)
            .background(NativeTheme.surface2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
            .padding(.horizontal, 18)
    }
}

private extension View {
    func nativeFieldStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .foregroundStyle(NativeTheme.text)
            .background(NativeTheme.surface, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NativeTheme.border))
    }
}
