//
//  SettingsView.swift
//  LearnChinese
//

import SwiftUI

struct SettingsView: View {
    @State private var hskRange = SharedStore.hskRange

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AppSelectionView()
                } label: {
                    Label("Apps to block", systemImage: "hand.raised.fill")
                }
            }

            Section("Daily Mission") {
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
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hskRange = SharedStore.hskRange }
    }

    private var hskMinBinding: Binding<Int> {
        Binding(
            get: { hskRange.min },
            set: { newMin in
                hskRange = hskRange.updatingMin(newMin)
                SharedStore.hskRange = hskRange
            }
        )
    }

    private var hskMaxBinding: Binding<Int> {
        Binding(
            get: { hskRange.max },
            set: { newMax in
                hskRange = hskRange.updatingMax(newMax)
                SharedStore.hskRange = hskRange
            }
        )
    }
}
