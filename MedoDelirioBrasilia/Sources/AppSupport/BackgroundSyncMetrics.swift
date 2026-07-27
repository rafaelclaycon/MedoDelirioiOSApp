//
//  BackgroundSyncMetrics.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/07/26.
//

import Foundation

/// Queues analytics for background sync runs and sends them on the next foreground.
///
/// Background wakes are time-budgeted and suspend moments after finishing, so a request
/// fired at the end of a run often never leaves the device — which would silently bias
/// the data toward interrupted runs. Recording locally first loses nothing and costs the
/// budget nothing.
@MainActor
enum BackgroundSyncMetrics {

    private static let storageKey = "pendingBackgroundSyncMetrics"
    private static let maxQueuedEntries = 50

    /// Appends the event stamped with its real occurrence time — `UsageMetric.dateTime`
    /// will carry the flush time, which can be hours later.
    static func record(_ action: String) {
        var pending = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        pending.append("\(action) @ \(Date.now.iso8601withFractionalSeconds)")
        if pending.count > maxQueuedEntries {
            pending.removeFirst(pending.count - maxQueuedEntries)
        }
        UserDefaults.standard.set(pending, forKey: storageKey)
    }

    /// Drains the queue through the regular analytics pipeline. Best-effort: entries are
    /// cleared up front so a failed send drops data instead of ever duplicating it.
    static func flush() {
        let pending = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        guard !pending.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: storageKey)

        Task {
            let service = AnalyticsService()
            for entry in pending {
                await service.send(originatingScreen: "BackgroundSync", action: entry)
            }
        }
    }
}
