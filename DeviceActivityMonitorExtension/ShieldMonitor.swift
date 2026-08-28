//
//  ShieldMonitor.swift
//  DeviceActivityMonitorExtension
//
//  Re-applies (or clears) the app shield from the Device Activity extension so
//  blocking continues even when the main app is not open.
//

import DeviceActivity
import FamilyControls
import ManagedSettings
import Foundation

private enum SharedConfig {
    static let appGroup = "group.adamkuzma.LearnChinese"
    static let storeName = "LearnChineseShield"
    static let selectionKey = "blockedSelection"
    static let unlockUntilKey = "unlockUntil"
    static let energyDayStartKey = "energyDayStart"
    static let unlockThresholdEventName = "LearnChineseUnlockThreshold"
}

class ShieldMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .init(SharedConfig.storeName))

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        syncShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        syncShield()
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        syncShield()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        // Usage of a blocked app reached the unlock length. Re-apply even if the
        // wall-clock timestamp is a few seconds in the future.
        syncShield(forceBlock: event.rawValue == SharedConfig.unlockThresholdEventName)
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        syncShield()
    }

    private func syncShield(forceBlock: Bool = false) {
        let defaults = UserDefaults(suiteName: SharedConfig.appGroup)
        let now = Date()

        if let dayStart = defaults?.double(forKey: SharedConfig.energyDayStartKey),
           dayStart > 0 {
            let storedDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: dayStart))
            if storedDay < Calendar.current.startOfDay(for: now) {
                defaults?.removeObject(forKey: SharedConfig.unlockUntilKey)
            }
        }

        let unlockUntil = defaults?.double(forKey: SharedConfig.unlockUntilKey) ?? 0
        if !forceBlock, unlockUntil > now.timeIntervalSince1970 {
            clearShield()
            return
        }

        defaults?.removeObject(forKey: SharedConfig.unlockUntilKey)

        guard let data = defaults?.data(forKey: SharedConfig.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        else {
            clearShield()
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}
