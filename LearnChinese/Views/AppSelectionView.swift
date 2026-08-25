//
//  AppSelectionView.swift
//  LearnChinese
//

import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @State private var showPicker = false
    @State private var draftSelection = FamilyActivitySelection()

    var body: some View {
        List {
            Section {
                Button {
                    draftSelection = blocker.selection
                    showPicker = true
                } label: {
                    Label("Choose apps & categories", systemImage: "square.grid.2x2")
                }
            } footer: {
                Text("Current lesson: \(blocker.sessionMode.title) (\(blocker.sessionMode.summary)).")
            }

            Section("Currently selected") {
                let appCount = blocker.selection.applicationTokens.count
                let categoryCount = blocker.selection.categoryTokens.count

                if appCount == 0 && categoryCount == 0 {
                    Text("Nothing selected")
                        .foregroundStyle(.secondary)
                } else {
                    Label("\(appCount) app\(appCount == 1 ? "" : "s")", systemImage: "app.badge")
                    if categoryCount > 0 {
                        Label("\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")", systemImage: "folder")
                    }
                    Button("Clear selection", role: .destructive) {
                        blocker.updateSelection(FamilyActivitySelection())
                    }
                }
            }
        }
        .navigationTitle("Apps to block")
        .familyActivityPicker(isPresented: $showPicker, selection: $draftSelection)
        .onChange(of: showPicker) { _, isShowing in
            if !isShowing {
                blocker.updateSelection(draftSelection)
            }
        }
    }
}
