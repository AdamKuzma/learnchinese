//
//  LearnChineseApp.swift
//  LearnChinese
//
//  Created by Adam Kuzma on 6/21/26.
//

import SwiftUI
import SwiftData

@main
struct LearnChineseApp: App {
    // TEST COMMENT: verify this change shows up in GitHub / Cursor.
    @StateObject private var blocker = AppBlocker()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppChrome.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blocker)
                .tint(Color.appAccent)
                .foregroundStyle(Color.appForeground)
                .task {
                    Task.detached(priority: .utility) {
                        HSKCatalog.warm()
                    }
                    await blocker.requestAuthorization()
                    blocker.refreshShieldState()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        blocker.refreshShieldState()
                    }
                }
        }
        .modelContainer(for: [Flashcard.self, ItemProgress.self])
    }
}
