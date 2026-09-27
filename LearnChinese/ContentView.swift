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
        .modelContainer(PreviewStore.container)
}

private enum PreviewStore {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Flashcard.self, ItemProgress.self, DailyActivity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let samples = [0: 6, -1: 2, -2: 5, -3: 1, -4: 4, -6: 1, -8: 3]
        for (offset, count) in samples {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            container.mainContext.insert(DailyActivity(dayStart: day, count: count))
        }
        try? container.mainContext.save()
        return container
    }()
}
