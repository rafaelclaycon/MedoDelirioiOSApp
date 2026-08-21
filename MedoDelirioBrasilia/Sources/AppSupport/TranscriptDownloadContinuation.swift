//
//  TranscriptDownloadContinuation.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/08/26.
//

import UIKit

/// Buys a transcript sync that is already running the short grace period iOS grants
/// after the user switches away, so a download in progress isn't cut off the moment
/// they leave.
///
/// **Grace period only, by design.** Unlike `ContentUpdateContinuation`, this never
/// submits a `BGContinuedProcessingTask` and never schedules a background wake:
/// transcripts are an opt-in extra that nobody is watching a progress banner for, and
/// waking the app for them isn't wanted. The system grants a matter of seconds here —
/// enough to finish a handful of files. Whatever doesn't fit is picked up by the next
/// foreground sync, since every SRT is written atomically and the manifest diff simply
/// sees the remainder as still missing.
@MainActor
enum TranscriptDownloadContinuation {

    private static var gracePeriodTaskID: UIBackgroundTaskIdentifier = .invalid

    /// - Parameters:
    ///   - isStillDownloading: polled to know when the work is done and the time can be
    ///     handed back. Holding a background task longer than needed is what gets an app
    ///     killed by the watchdog.
    ///   - requestStop: called when the grace period runs out. The sync stops at the next
    ///     whole file rather than being killed mid-write.
    static func beginGracePeriod(
        isStillDownloading: @escaping @MainActor () -> Bool,
        requestStop: @escaping @MainActor () -> Void
    ) {
        guard gracePeriodTaskID == .invalid else { return }

        gracePeriodTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "SincronizacaoDeTranscricoes"
        ) {
            MainActor.assumeIsolated {
                BackgroundContentSync.log("📝 Transcrições: tempo extra esgotado")
                requestStop()
                endGracePeriod()
            }
        }

        // The system can refuse outright, in which case there is nothing to wait on and
        // no task to end.
        guard gracePeriodTaskID != .invalid else {
            BackgroundContentSync.log("📝 Transcrições: sistema negou tempo extra")
            return
        }

        BackgroundContentSync.log("📝 Transcrições: tempo extra concedido para terminar o sync")

        Task { @MainActor in
            while isStillDownloading() {
                try? await Task.sleep(for: .seconds(1))
            }
            endGracePeriod()
        }
    }

    private static func endGracePeriod() {
        guard gracePeriodTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(gracePeriodTaskID)
        gracePeriodTaskID = .invalid
    }
}
