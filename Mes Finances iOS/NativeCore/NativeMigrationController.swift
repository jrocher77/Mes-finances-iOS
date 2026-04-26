//
//  NativeMigrationController.swift
//  Mes Finances iOS
//
//  Coordinates native auth + Firestore read-only loading during migration.
//

import Foundation
import Combine

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
#endif

@MainActor
final class NativeMigrationController: ObservableObject {
    enum AuthState: Equatable {
        case unavailable
        case checking
        case signedOut
        case signedIn(uid: String)
    }

    @Published private(set) var authState: AuthState = .checking
    @Published private(set) var isLoadingDocument = false
    @Published var errorMessage: String?

    let store = NativeFinanceStore()

    #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
    private var service: FirebaseBudgetService?
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    #endif

    init() {
        #if !(canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore))
        authState = .unavailable
        #endif
    }

    func start() {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard FirebaseApp.app() != nil else {
            authState = .unavailable
            return
        }

        if service == nil {
            service = FirebaseBudgetService()
        }

        guard authHandle == nil else { return }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleAuthUser(uid: user?.uid)
            }
        }
        #else
        authState = .unavailable
        #endif
    }

    func signIn(email: String, password: String) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard let service else {
            authState = .unavailable
            errorMessage = "Ajoute GoogleService-Info.plist pour activer Firebase natif."
            return
        }

        errorMessage = nil
        do {
            let uid = try await service.signIn(email: email, password: password)
            handleAuthUser(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        #else
        errorMessage = "Firebase natif n'est pas disponible dans ce build."
        #endif
    }

    func signOut() {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard let service else { return }

        do {
            try service.signOut()
            handleAuthUser(uid: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func stop() {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
            self.authHandle = nil
        }
        #endif
    }

    private func handleAuthUser(uid: String?) {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        listener?.remove()
        listener = nil
        #endif

        guard let uid else {
            authState = .signedOut
            isLoadingDocument = false
            return
        }

        authState = .signedIn(uid: uid)
        subscribeToBudget(uid: uid)
    }

    private func subscribeToBudget(uid: String) {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        guard let service else {
            authState = .unavailable
            errorMessage = "Ajoute GoogleService-Info.plist pour activer Firebase natif."
            return
        }

        isLoadingDocument = true
        errorMessage = nil

        listener = service.subscribe(
            uid: uid,
            onUpdate: { [weak self] document, metadata in
                guard let self else { return }
                isLoadingDocument = false

                guard let document else {
                    store.replaceDocument(UserBudgetDocument())
                    errorMessage = metadata?.isFromCache == true
                        ? "Aucune donnee native dans le cache Firebase."
                        : "Aucun document budget trouve pour ce compte."
                    return
                }

                store.replaceDocument(document)
                errorMessage = nil
            },
            onError: { [weak self] error in
                guard let self else { return }
                isLoadingDocument = false
                errorMessage = error.localizedDescription
            }
        )
        #endif
    }
}
