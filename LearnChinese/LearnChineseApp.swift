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
    @StateObject private var blocker = AppBlocker()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(blocker)
                .task {
                    await blocker.requestAuthorization()
                    blocker.refreshShieldState()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        blocker.refreshShieldState()
                    }
                }
        }
        .modelContainer(for: Flashcard.self)
    }
}
