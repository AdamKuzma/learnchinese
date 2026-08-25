//
//  ContentView.swift
//  LearnChinese
//
//  Created by Adam Kuzma on 6/21/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppBlocker())
        .modelContainer(for: Flashcard.self, inMemory: true)
}
