//
//  SettingsView.swift
//  LearnChinese
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @State private var hskRange = HSKRange.default

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AppSelectionView()
                } label: {
                    Label("Apps to block", systemImage: "hand.raised.fill")
                }
            }

            Section {
                Picker("From", selection: hskMinBinding) {
                    ForEach(Array(HSKRange.levels), id: \.self) { level in
                        Text("HSK \(level)").tag(level)
                    }
                }
                .pickerStyle(.menu)

                Picker("To", selection: hskMaxBinding) {
                    ForEach(Array(HSKRange.levels), id: \.self) { level in
                        Text("HSK \(level)").tag(level)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Daily Mission")
            } footer: {
                Text("HSK 3.0 vocabulary and grammar, levels 1–6.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hskRange = blocker.hskRange }
    }

    private var hskMinBinding: Binding<Int> {
        Binding(
            get: { hskRange.min },
            set: { newMin in
                hskRange = hskRange.updatingMin(newMin)
                blocker.updateHSKRange(hskRange)
            }
        )
    }

    private var hskMaxBinding: Binding<Int> {
        Binding(
            get: { hskRange.max },
            set: { newMax in
                hskRange = hskRange.updatingMax(newMax)
                blocker.updateHSKRange(hskRange)
            }
        )
    }
}
