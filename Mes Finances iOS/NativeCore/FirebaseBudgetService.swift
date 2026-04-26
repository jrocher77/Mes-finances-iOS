//
//  FirebaseBudgetService.swift
//  Mes Finances iOS
//
//  Native Firebase bridge for the progressive SwiftUI migration.
//

import Foundation

#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

enum FirebaseBudgetServiceError: Error {
    case invalidDocumentPayload
    case encodingFailed
}

final class FirebaseBudgetService {
    private let db: Firestore
    private let auth: Auth
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = db
        self.auth = auth
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    var currentUserId: String? {
        auth.currentUser?.uid
    }

    func signIn(email: String, password: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            auth.signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else {
                    continuation.resume(throwing: FirebaseBudgetServiceError.invalidDocumentPayload)
                    return
                }

                continuation.resume(returning: result.user.uid)
            }
        }
    }

    func signOut() throws {
        try auth.signOut()
    }

    @discardableResult
    func subscribe(
        uid: String,
        onUpdate: @escaping @MainActor (UserBudgetDocument?, SnapshotMetadata?) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> ListenerRegistration {
        db.collection("budgets").document(uid).addSnapshotListener { [weak self] snapshot, error in
            if let error {
                Task { @MainActor in onError(error) }
                return
            }

            guard let self else { return }
            guard let snapshot, snapshot.exists, let data = snapshot.data() else {
                Task { @MainActor in onUpdate(nil, snapshot?.metadata) }
                return
            }

            do {
                let document = try self.decodeBudgetDocument(from: data)
                Task { @MainActor in onUpdate(document, snapshot.metadata) }
            } catch {
                Task { @MainActor in onError(error) }
            }
        }
    }

    func save(uid: String, document: UserBudgetDocument, merge: Bool = true) async throws {
        let payload = try encodeBudgetDocument(document)
        try await savePartial(uid: uid, payload: payload, merge: merge)
    }

    func savePartial(uid: String, payload: [String: Any], merge: Bool = true) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.collection("budgets").document(uid).setData(payload, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func decodeBudgetDocument(from data: [String: Any]) throws -> UserBudgetDocument {
        guard JSONSerialization.isValidJSONObject(data) else {
            throw FirebaseBudgetServiceError.invalidDocumentPayload
        }
        let json = try JSONSerialization.data(withJSONObject: data)
        return try decoder.decode(UserBudgetDocument.self, from: json).normalizedForFirestore()
    }

    private func encodeBudgetDocument(_ document: UserBudgetDocument) throws -> [String: Any] {
        let data = try encoder.encode(document)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let payload = object as? [String: Any] else {
            throw FirebaseBudgetServiceError.encodingFailed
        }
        return payload.removingNulls()
    }
}

private extension Dictionary where Key == String, Value == Any {
    func removingNulls() -> [String: Any] {
        var cleaned: [String: Any] = [:]

        for (key, value) in self {
            if value is NSNull { continue }
            if let dict = value as? [String: Any] {
                cleaned[key] = dict.removingNulls()
                continue
            }
            if let array = value as? [Any] {
                cleaned[key] = array.map { item -> Any in
                    if let dict = item as? [String: Any] {
                        return dict.removingNulls()
                    }
                    return item
                }
                continue
            }
            cleaned[key] = value
        }

        return cleaned
    }
}
#endif

extension UserBudgetDocument {
    func normalizedForFirestore() -> UserBudgetDocument {
        var copy = self
        copy.transactions = transactions.map { transaction in
            var copy = transaction
            copy.pointed = transaction.pointed
            return copy
        }
        copy.accounts = accounts.map { account in
            var copy = account
            if copy.type == .savings && copy.savingsSubtype == nil {
                copy.savingsSubtype = .available
            }
            return copy
        }
        if copy.accounts.isEmpty {
            copy.accounts = [FinanceAccount(name: "Compte courant")]
        }
        return copy
    }
}
