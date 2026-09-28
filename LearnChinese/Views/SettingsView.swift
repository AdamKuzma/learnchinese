//
//  SettingsView.swift
//  LearnChinese
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var blocker: AppBlocker
    @State private var hskLevel = SharedStore.hskLevel
    @State private var missionDifficulty = SharedStore.missionDifficulty
    @State private var missionVocabSource = SharedStore.missionVocabSource
    @State private var missionThemes = SharedStore.missionThemes

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AppSelectionView()
                } label: {
                    Label("Apps to block", systemImage: "hand.raised.fill")
                }
            }
            .appListRowBackground()

            Section {
                AppSectionHeader(title: "Lesson settings")
                    .padding(.top, 16)
                    .appListSectionTitle()

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Mode", selection: sessionModeBinding) {
                        ForEach(SessionMode.allCases) { mode in
                            Text("\(mode.title): \(mode.summary)").tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Question type", selection: questionTypeBinding) {
                        ForEach(QuestionTypeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .appListRowBackground()
            }

            Section {
                AppSectionHeader(title: "Daily Mission")
                    .padding(.top, 16)
                    .appListSectionTitle()

                VStack(alignment: .leading, spacing: 22) {
                    StopSlider(
                        title: { "HSK \($0)" },
                        stops: Array(HSKRange.levels),
                        value: hskLevelBinding,
                        accessibilityLabel: "HSK level"
                    )

                    StopSlider(
                        title: { $0.title },
                        stops: Array(MissionDifficulty.allCases),
                        value: missionDifficultyBinding,
                        accessibilityLabel: "Difficulty"
                    )

                    Picker("Vocabulary", selection: missionVocabSourceBinding) {
                        ForEach(MissionVocabSource.allCases) { source in
                            Text(source.settingsTitle).tag(source)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .appListRowBackground()
            }

            Section {
                AppSectionHeader(title: "Theme")
                    .padding(.top, 16)
                    .appListSectionTitle()

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(MissionTheme.allCases.enumerated()), id: \.element) { index, theme in
                        if index > 0 {
                            Color.appSecondaryBorder
                                .frame(height: 0.5)
                        }

                        Button {
                            toggleTheme(theme)
                        } label: {
                            HStack {
                                Text(theme.title)
                                    .foregroundStyle(Color.appForeground)
                                Spacer()
                                if missionThemes.contains(theme) {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .appListRowBackground()
            }
        }
        .appListChrome()
        .listSectionSpacing(20)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hskLevel = SharedStore.hskLevel
            missionDifficulty = SharedStore.missionDifficulty
            missionVocabSource = SharedStore.missionVocabSource
            missionThemes = SharedStore.missionThemes
        }
    }

    private var sessionModeBinding: Binding<SessionMode> {
        Binding(
            get: { blocker.sessionMode },
            set: { blocker.updateSessionMode($0) }
        )
    }

    private var questionTypeBinding: Binding<QuestionTypeMode> {
        Binding(
            get: { blocker.questionTypeMode },
            set: { blocker.updateQuestionTypeMode($0) }
        )
    }

    private var hskLevelBinding: Binding<Int> {
        Binding(
            get: { hskLevel },
            set: { newLevel in
                hskLevel = newLevel
                SharedStore.hskLevel = newLevel
            }
        )
    }

    private var missionDifficultyBinding: Binding<MissionDifficulty> {
        Binding(
            get: { missionDifficulty },
            set: { newDifficulty in
                missionDifficulty = newDifficulty
                SharedStore.missionDifficulty = newDifficulty
            }
        )
    }

    private var missionVocabSourceBinding: Binding<MissionVocabSource> {
        Binding(
            get: { missionVocabSource },
            set: { newSource in
                missionVocabSource = newSource
                SharedStore.missionVocabSource = newSource
            }
        )
    }

    private func toggleTheme(_ theme: MissionTheme) {
        if missionThemes.contains(theme) {
            guard missionThemes.count > 1 else { return }
            missionThemes.remove(theme)
        } else {
            missionThemes.insert(theme)
        }
        SharedStore.missionThemes = missionThemes
    }
}

private struct StopSlider<Value: Hashable>: View {
    let title: (Value) -> String
    let stops: [Value]
    @Binding var value: Value
    let accessibilityLabel: String

    private let trackHeight: CGFloat = 24
    private let thumbSize: CGFloat = 28
    private let tickSize: CGFloat = 5
    private let trackInset: CGFloat = 16
    private let fillColor = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let trackColor = Color.white.opacity(0.18)
    private let tickColor = Color.white.opacity(0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title(value))
                .font(.body)

            GeometryReader { geometry in
                let width = geometry.size.width
                let progress = CGFloat(selectedIndex) / CGFloat(max(stops.count - 1, 1))
                let thumbX = xPosition(for: progress, width: width)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(trackColor)
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(fillColor)
                        .frame(width: max(trackHeight, thumbX), height: trackHeight)

                    ForEach(Array(stops.enumerated()), id: \.offset) { index, _ in
                        Circle()
                            .fill(tickColor)
                            .frame(width: tickSize, height: tickSize)
                            .offset(x: xPosition(for: index, width: width) - tickSize / 2)
                    }

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
                        .offset(x: thumbX - thumbSize / 2)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            value = snappedValue(at: drag.location.x, width: width)
                        }
                )
            }
            .frame(height: thumbSize)
        }
        .padding(.vertical, 4)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(title(value))
        .accessibilityAdjustableAction { direction in
            let index = selectedIndex
            switch direction {
            case .increment:
                if index + 1 < stops.count {
                    value = stops[index + 1]
                }
            case .decrement:
                if index > 0 {
                    value = stops[index - 1]
                }
            default:
                break
            }
        }
    }

    private var selectedIndex: Int {
        stops.firstIndex(of: value) ?? 0
    }

    private func usableWidth(in width: CGFloat) -> CGFloat {
        max(width - 2 * trackInset, 1)
    }

    private func xPosition(for index: Int, width: CGFloat) -> CGFloat {
        xPosition(for: CGFloat(index) / CGFloat(max(stops.count - 1, 1)), width: width)
    }

    private func xPosition(for progress: CGFloat, width: CGFloat) -> CGFloat {
        trackInset + progress * usableWidth(in: width)
    }

    private func snappedValue(at x: CGFloat, width: CGFloat) -> Value {
        guard width > 0, !stops.isEmpty else { return value }
        let progress = min(1, max(0, (x - trackInset) / usableWidth(in: width)))
        let raw = Int((progress * CGFloat(stops.count - 1)).rounded())
        return stops[min(stops.count - 1, max(0, raw))]
    }
}
