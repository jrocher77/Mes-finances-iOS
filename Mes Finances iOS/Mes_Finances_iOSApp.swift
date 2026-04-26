//
//  Mes_Finances_iOSApp.swift
//  Mes Finances iOS
//
//  Created by JEREMY on 23/04/2026.
//

import SwiftUI

@main
struct Mes_Finances_iOSApp: App {
    init() {
        FirebaseBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
