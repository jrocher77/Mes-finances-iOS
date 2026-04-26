//
//  FirebaseBootstrap.swift
//  Mes Finances iOS
//
//  Firebase configuration shared by the native migration layer.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore

enum FirebaseBootstrap {
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static func configureIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            #if DEBUG
            print("[FirebaseBootstrap] GoogleService-Info.plist absent. Mode natif Firebase indisponible.")
            #endif
            return
        }

        FirebaseApp.configure()
    }
}
#else
enum FirebaseBootstrap {
    static var isConfigured: Bool {
        false
    }

    static func configureIfNeeded() {
    }
}
#endif
