//
//  TranscriptDownloadContinuation.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/08/26.
//

import BackgroundTasks
import UIKit

/// Keeps a transcript download going after the user switches away.
///
/// Two levels, depending on who started it:
///
/// - **The opt-in download** — the whole catalog, close to a thousand files, started by
///   the user and shown with a progress banner — submits a `BGContinuedProcessingTask`.
///   The system keeps it running in the background and shows its progress in the
///   Dynamic Island and on the Lock Screen, like `ContentUpdateContinuation` does for
///   content.
/// - **Any other sync** in flight gets only the short grace period iOS grants after the
///   user leaves: a matter of seconds, enough for a handful of files. Those are small
///   catch-up runs nobody is watching, so they never get system progress UI.
///
/// Neither schedules a background wake of its own. Whatever doesn't finish is picked up
/// by the next check, in the foreground or on the scheduled content refresh
/// (`BackgroundContentSync`), since every SRT is written atomically and the manifest
/// diff simply sees the remainder as still missing.
@MainActor
enum TranscriptDownloadContinuation {

    private static var gracePeriodTaskID: UIBackgroundTaskIdentifier = .invalid
    private static var isContinuedTaskRunning = false
    private static var isHandlerRegistered = false
    private static var didExpire = false

    /// The submitting app's bundle ID must prefix the identifier, so it can't be a
    /// constant — the beta target ships under a different one. Only one download ever
    /// runs at a time, so a stable identifier is enough. Permitted in Info.plist by the
    /// `.transcriptDownload.*` wildcard; the wildcard itself is never submitted, since
    /// `BGTaskScheduler` matches handlers by exact identifier and submitting one it has
    /// no handler for aborts the process.
    private static var taskIdentifier: String {
        (Bundle.main.bundleIdentifier ?? "com.rafaelschmitt.MedoDelirioBrasilia") + ".transcriptDownload.sync"
    }

    // MARK: - Setup

    /// Must be called before the app finishes launching.
    static func register() {
        isHandlerRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else { return }
            Task { @MainActor in
                await run(continuedTask)
            }
        }
        BackgroundContentSync.log("📝 Handler de continuação de transcrições registrado: \(isHandlerRegistered)")
    }

    // MARK: - Continued Processing

    /// Asks the system to keep the opt-in download running once the user leaves. Called
    /// when the download starts, since a request can only be submitted from the
    /// foreground.
    static func beginContinuedDownload() {
        guard !isContinuedTaskRunning else { return }
        guard UIApplication.shared.applicationState != .background else {
            BackgroundContentSync.log("📝 Continuação de transcrições não solicitada (app em segundo plano)")
            return
        }
        // Submitting without a registered handler aborts the process rather than throwing.
        guard isHandlerRegistered else {
            BackgroundContentSync.log("📝 Continuação de transcrições indisponível: handler não registrado")
            return
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: title,
            subtitle: subtitle(progress: 0)
        )
        // Queueing rather than failing: a busy system should delay us, not drop the work.
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
            BackgroundContentSync.log("📝 Continuação de transcrições enviada ao sistema")
        } catch {
            BackgroundContentSync.log("📝 Falha ao enviar continuação de transcrições: \(error)")
        }
    }

    private static let title = "Baixando transcrições"

    private static func subtitle(progress: Double) -> String {
        "\(Int(progress * 100))% completado"
    }

    /// Mirrors the download's progress onto the task for as long as it runs. The system
    /// expires tasks that look stalled, so reporting has to continue throughout.
    private static func run(_ task: BGContinuedProcessingTask) async {
        BackgroundContentSync.log("📝 Continuação de transcrições iniciada pelo sistema")

        isContinuedTaskRunning = true
        didExpire = false
        defer { isContinuedTaskRunning = false }

        let service = TranscriptDownloadService.shared

        // The user tapping the system UI's stop control and the system reclaiming
        // resources both arrive here, and both want the same thing: stop at the next
        // whole file. What's missing is fetched by the next check.
        task.expirationHandler = {
            Task { @MainActor in
                BackgroundContentSync.log("📝 Continuação de transcrições encerrada (parada pelo usuário ou expirada pelo sistema)")
                didExpire = true
                service.stopAtNextFile()
            }
        }

        // Whole percent steps keep the system's bar honest without a count of files,
        // which the service doesn't expose.
        task.progress.totalUnitCount = 100

        while service.isDownloading, !didExpire {
            // The documented stop signal is the expiration handler; the progress object's
            // cancellation state is watched as well in case the system ever signals only there.
            if task.progress.isCancelled {
                didExpire = true
                service.stopAtNextFile()
                break
            }
            report(service.state, to: task)
            try? await Task.sleep(for: .seconds(1))
        }

        if didExpire {
            BackgroundSyncMetrics.record("transcript_continuation_ended(stopped)")
            task.setTaskCompleted(success: false)
        } else {
            let succeeded = service.state == .completed
            if succeeded {
                task.progress.completedUnitCount = task.progress.totalUnitCount
                task.updateTitle("Transcrições baixadas", subtitle: "Agora dá pra buscar em todos os episódios.")
            }
            BackgroundSyncMetrics.record("transcript_continuation_ended(\(succeeded ? "completed" : "failed"))")
            task.setTaskCompleted(success: succeeded)
        }

        BackgroundContentSync.log("📝 Continuação de transcrições encerrada")
    }

    private static func report(_ state: TranscriptDownloadService.State, to task: BGContinuedProcessingTask) {
        guard case .downloading(let progress) = state else { return }
        task.progress.completedUnitCount = Int64(progress * 100)
        task.updateTitle(title, subtitle: subtitle(progress: progress))
    }

    // MARK: - Grace Period

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
        // A live continued-processing task already keeps the download running.
        guard !isContinuedTaskRunning else { return }
        guard gracePeriodTaskID == .invalid else { return }

        gracePeriodTaskID = UIApplication.shared.beginBackgroundTask(
            withName: "SincronizacaoDeTranscricoes"
        ) {
            MainActor.assumeIsolated {
                BackgroundContentSync.log("📝 Transcrições: tempo extra esgotado")
                // A queued continued-processing task may have started meanwhile and taken
                // over: then the download must keep going, and only this hold ends.
                if !isContinuedTaskRunning {
                    requestStop()
                }
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
