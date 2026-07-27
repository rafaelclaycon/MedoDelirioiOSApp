//
//  ContentUpdateContinuation.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/07/26.
//

import BackgroundTasks
import UIKit

/// Keeps a long content update going after the user leaves the app.
///
/// On iOS 26 the system grants real background runtime through `BGContinuedProcessingTask`
/// and shows its own progress UI in the Dynamic Island and on the Lock Screen. Earlier
/// systems only get a short grace period, after which the update pauses — unfinished
/// events stay marked unsuccessful and are retried later, so stopping midway is safe.
@MainActor
enum ContentUpdateContinuation {

    private static var gracePeriodTaskID: UIBackgroundTaskIdentifier = .invalid
    private static var isContinuedTaskRunning = false
    private static var isHandlerRegistered = false
    private static var didExpire = false

    /// Whether the system agreed to keep the current update running once the user leaves.
    /// The banner tells people they can walk away based on this, so it has to reflect the
    /// actual grant — the OS version alone doesn't guarantee one.
    private(set) static var isBackgroundContinuationGranted = false

    /// The submitting app's bundle ID must prefix the identifier, so it can't be a
    /// constant — the beta target ships under a different one.
    private static var identifierPrefix: String {
        (Bundle.main.bundleIdentifier ?? "com.rafaelschmitt.MedoDelirioBrasilia") + ".contentUpdate"
    }

    /// Submitted and registered as-is. `BGTaskScheduler` matches launch handlers by exact
    /// identifier — submitting anything it has no handler for aborts the process — so the
    /// wildcard form belongs only in `BGTaskSchedulerPermittedIdentifiers`, which is what
    /// permits this concrete identifier. Only one update ever runs at a time, so a stable
    /// identifier is enough and keeps registration to a single call.
    private static var taskIdentifier: String {
        identifierPrefix + ".sync"
    }

    // MARK: - Setup

    static func register() {
        guard #available(iOS 26.0, *) else { return }

        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let continuedTask = task as? BGContinuedProcessingTask else { return }
            Task { @MainActor in
                await run(continuedTask)
            }
        }
        isHandlerRegistered = registered
        BackgroundContentSync.log("🏝️ Handler de continuação registrado: \(registered)")
    }

    // MARK: - Entry Points

    /// Asks the system to let the in-flight update survive backgrounding. Called when a
    /// run turns out to be long enough to be worth showing outside the app.
    static func begin() {
        isBackgroundContinuationGranted = false

        guard #available(iOS 26.0, *) else { return }
        guard !isContinuedTaskRunning else { return }
        // Submitting without a registered handler aborts the process rather than throwing.
        guard isHandlerRegistered else {
            BackgroundContentSync.log("🏝️ Continuação indisponível: handler não registrado")
            return
        }

        let service = ContentUpdateService.shared
        let request = BGContinuedProcessingTaskRequest(
            identifier: taskIdentifier,
            title: "Baixando novidades",
            subtitle: subtitle(processed: service.processedUpdateNumber, total: service.totalUpdateCount)
        )
        // Queueing rather than failing: a busy system should delay us, not drop the work.
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
            isBackgroundContinuationGranted = true
            BackgroundContentSync.log("🏝️ Continuação enviada ao sistema")
        } catch {
            BackgroundContentSync.log("🏝️ Falha ao enviar continuação: \(error)")
        }
    }

    /// Buys extra seconds for an update caught in progress when the user leaves.
    /// A live continued-processing task already covers this, so it takes over only
    /// where that API doesn't exist or wasn't granted.
    static func appDidEnterBackground() {
        guard ContentUpdateService.shared.isUpdating else { return }
        guard !isContinuedTaskRunning else { return }
        guard gracePeriodTaskID == .invalid else { return }

        gracePeriodTaskID = UIApplication.shared.beginBackgroundTask(withName: "AtualizacaoDeConteudo") {
            MainActor.assumeIsolated {
                BackgroundContentSync.log("🏝️ Tempo extra esgotado")
                endGracePeriod()
            }
        }
        BackgroundContentSync.log("🏝️ Tempo extra solicitado para terminar a atualização")

        Task { @MainActor in
            while ContentUpdateService.shared.isUpdating {
                try? await Task.sleep(for: .seconds(1))
            }
            endGracePeriod()
        }
    }

    // MARK: - Internal

    private static func endGracePeriod() {
        guard gracePeriodTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(gracePeriodTaskID)
        gracePeriodTaskID = .invalid
    }

    private static func subtitle(processed: Int, total: Int) -> String {
        guard total > 0 else { return "Preparando..." }
        return "\(processed) de \(total)"
    }

    /// Mirrors the update's progress onto the task for as long as it runs. The system
    /// expires tasks that look stalled, so reporting has to continue throughout.
    @available(iOS 26.0, *)
    private static func run(_ task: BGContinuedProcessingTask) async {
        BackgroundContentSync.log("🏝️ Continuação iniciada pelo sistema")

        isContinuedTaskRunning = true
        didExpire = false
        defer {
            isContinuedTaskRunning = false
        }

        task.expirationHandler = {
            Task { @MainActor in
                BackgroundContentSync.log("🏝️ Continuação expirada pelo sistema")
                didExpire = true
            }
        }

        let service = ContentUpdateService.shared

        while service.isUpdating, !didExpire {
            report(service: service, to: task)
            try? await Task.sleep(for: .seconds(1))
        }

        if didExpire {
            task.setTaskCompleted(success: false)
        } else {
            report(service: service, to: task)
            task.progress.completedUnitCount = task.progress.totalUnitCount
            task.setTaskCompleted(success: service.lastUpdateStatus == .done)
        }

        BackgroundContentSync.log("🏝️ Continuação encerrada")
    }

    @available(iOS 26.0, *)
    private static func report(service: ContentUpdateService, to task: BGContinuedProcessingTask) {
        // Never zero: a total of 0 would make the system's progress bar meaningless.
        task.progress.totalUnitCount = Int64(max(service.totalUpdateCount, 1))
        task.progress.completedUnitCount = Int64(service.processedUpdateNumber)
        task.updateTitle(
            "Baixando novidades",
            subtitle: subtitle(processed: service.processedUpdateNumber, total: service.totalUpdateCount)
        )
    }
}
