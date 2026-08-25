//
//  AppBlocker.swift
//  LearnChinese
//
//  Coordinates Screen Time authorization, applying/clearing the app shield, and
//  scheduling automatic re-blocking after the configured unlock window.
//

import Foundation
import Combine
import FamilyControls
import ManagedSettings
import DeviceActivity

@MainActor
final class AppBlocker: ObservableObject {
    @Published var selection: FamilyActivitySelection
    @Published var isAuthorized = false
    @Published var unlockUntil: Date?
    @Published var sessionMode: SessionMode
    @Published var questionTypeMode: QuestionTypeMode

    private let store = ManagedSettingsStore(named: .init(SharedStore.managedSettingsStoreName))
    private let center = DeviceActivityCenter()
    private let unlockActivity = DeviceActivityName(SharedStore.deviceActivityName)
    private let dailyActivity = DeviceActivityName(SharedStore.dailyDeviceActivityName)

    init() {
        self.selection = SharedStore.loadSelection()
        self.unlockUntil = SharedStore.unlockUntil
        self.sessionMode = SharedStore.sessionMode
        self.questionTypeMode = SharedStore.questionTypeMode
        self.isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    var hasBlockedApps: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    var isUnlocked: Bool {
        guard let unlockUntil else { return false }
        return unlockUntil > .now
    }

    var isBlocking: Bool {
        SharedStore.blockingEnabled && hasBlockedApps && !isUnlocked
    }

    func remainingEnergyMinutes(at now: Date = .now) -> Double {
        let today = Calendar.current.startOfDay(for: now)
        if let storedDay = SharedStore.energyDayStart.map({ Calendar.current.startOfDay(for: $0) }),
           storedDay < today {
            return 0
        }
        guard let unlockUntil, unlockUntil > now else { return 0 }
        return min(Double(Energy.capMinutes), unlockUntil.timeIntervalSince(now) / 60)
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Selection / blocking

    func updateSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        SharedStore.saveSelection(newSelection)
        SharedStore.blockingEnabled = hasBlockedApps
        refreshShieldState()
    }

    func updateSessionMode(_ newMode: SessionMode) {
        sessionMode = newMode
        SharedStore.sessionMode = newMode
    }

    func updateQuestionTypeMode(_ newMode: QuestionTypeMode) {
        questionTypeMode = newMode
        SharedStore.questionTypeMode = newMode
    }

    /// Re-applies (or clears) the shield based on the current persisted state.
    /// Safe to call on launch and whenever the app returns to the foreground.
    func refreshShieldState() {
        applyDailyResetIfNeeded()
        unlockUntil = SharedStore.unlockUntil

        if isUnlocked {
            clearShield()
            startDailyMonitoring()
        } else if SharedStore.blockingEnabled && hasBlockedApps {
            SharedStore.unlockUntil = nil
            unlockUntil = nil
            applyShield()
            startDailyMonitoring()
        } else {
            clearShield()
            center.stopMonitoring()
        }
    }

    private func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    // MARK: - Unlock

    /// Called once the user has answered enough flashcards correctly.
    func startUnlock(mode: SessionMode? = nil) {
        let selectedMode = mode ?? sessionMode
        addEnergy(minutes: selectedMode.unlockMinutes)
    }

    /// Adds unlock energy in minutes, capped at `Energy.capMinutes` and the end of today.
    /// Remaining energy drains as the unlock window runs; after it hits 0 it can be earned again.
    @discardableResult
    func addEnergy(minutes: Int) -> Int {
        applyDailyResetIfNeeded()

        let now = Date()
        let currentRemaining = max(0, unlockUntil?.timeIntervalSince(now) ?? 0)
        let requested = TimeInterval(max(0, minutes) * 60)
        let capSeconds = min(
            TimeInterval(Energy.capMinutes * 60),
            secondsUntilEndOfDay(from: now)
        )
        let newRemaining = min(capSeconds, currentRemaining + requested)
        let addedSeconds = max(0, newRemaining - currentRemaining)

        guard newRemaining > 1 else { return 0 }

        clearShield()
        let end = now.addingTimeInterval(newRemaining)
        SharedStore.unlockUntil = end
        SharedStore.energyDayStart = Calendar.current.startOfDay(for: now)
        unlockUntil = end
        scheduleReblock(unlockDuration: newRemaining)

        // Stopping the previous DeviceActivity schedule can race the extension and
        // put the shield back. Re-assert unlock after scheduling.
        SharedStore.unlockUntil = end
        unlockUntil = end
        clearShield()
        return Int(addedSeconds / 60)
    }

    private func applyDailyResetIfNeeded() {
        let today = Calendar.current.startOfDay(for: .now)
        let storedDay = SharedStore.energyDayStart.map { Calendar.current.startOfDay(for: $0) }

        if storedDay == today { return }

        SharedStore.energyDayStart = today
        if storedDay != nil {
            SharedStore.unlockUntil = nil
            unlockUntil = nil
        }
    }

    private func secondsUntilEndOfDay(from now: Date) -> TimeInterval {
        let calendar = Calendar.current
        guard let endOfDay = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else {
            return TimeInterval(Energy.capMinutes * 60)
        }
        return max(0, endOfDay.timeIntervalSince(now))
    }

    private func scheduleReblock(unlockDuration: TimeInterval) {
        startDailyMonitoring()
        center.stopMonitoring([unlockActivity])

        let calendar = Calendar.current
        let now = Date()
        // DeviceActivity intervals must be at least 15 minutes. Pad the schedule
        // if needed; the extension still re-blocks at the real unlockUntil.
        let scheduledDuration = max(unlockDuration, 15 * 60)
        let start = now.addingTimeInterval(-60)
        let end = now.addingTimeInterval(scheduledDuration)

        var warningTime: DateComponents?
        if unlockDuration + 30 < scheduledDuration {
            let minutesBeforeEnd = max(1, Int(((scheduledDuration - unlockDuration) / 60).rounded(.down)))
            warningTime = DateComponents(minute: minutesBeforeEnd)
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
            repeats: false,
            warningTime: warningTime
        )

        do {
            try center.startMonitoring(unlockActivity, during: schedule)
        } catch {
            // Daily monitoring still re-applies the shield at midnight, and
            // refreshShieldState() re-applies if the user opens the app.
        }
    }

    /// Keeps a repeating all-day Device Activity running so iOS can wake the
    /// monitor extension and re-apply shields without the main app being open.
    private func startDailyMonitoring() {
        guard hasBlockedApps else { return }
        if center.activities.contains(dailyActivity) { return }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        do {
            try center.startMonitoring(dailyActivity, during: schedule)
        } catch {
            // Unlock monitoring can still re-block; opening the app also re-applies.
        }
    }
}
