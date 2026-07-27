//
//  BackgroundContentSync.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/07/26.
//

import BackgroundTasks
import UIKit

/// Runs content updates while the app is in the background, triggered by
/// silent pushes and scheduled `BGAppRefreshTask` refreshes.
@MainActor
enum BackgroundContentSync {

    /// Also listed under `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    static let refreshTaskIdentifier = "com.rafaelschmitt.MedoDelirioBrasilia.contentRefresh"

    /// Set when a background run brings in new content. The content list reads it when
    /// it becomes active again, since its in-memory cache predates the background sync.
    private static var didUpdateInBackground = false

    /// Returns whether new content arrived while in the background, clearing the flag.
    static func consumePendingRefresh() -> Bool {
        defer { didUpdateInBackground = false }
        return didUpdateInBackground
    }

    /// Traces background work, which is awkward to inspect with breakpoints because it
    /// runs while the app is suspended. Compiled out of release builds.
    static func log(_ message: String) {
        #if DEBUG
        print(message)
        #endif
    }

    /// Registers the background refresh handler. Must be called before the app finishes launching.
    static func registerRefreshTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                handle(refreshTask)
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                scheduleRefresh()
                ContentUpdateContinuation.appDidEnterBackground()
            }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                BackgroundSyncMetrics.flush()
            }
        }
    }

    /// Asks the system for a future refresh. The date is a floor, not a promise —
    /// iOS decides the actual moment based on usage patterns and battery.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            log("⏰ BGAppRefresh: próxima atualização agendada (piso de 4 h)")
        } catch {
            log("⏰ Erro ao agendar atualização de conteúdo em segundo plano: \(error)")
        }
    }

    /// Runs a content update and maps the outcome to a background fetch result.
    /// Safe to call while a foreground update is in flight — it just reports no data.
    ///
    /// `budgetSeconds` caps the run for callers on a system deadline (silent push wakes
    /// get ~30 s and no expiration callback): the sync is asked to stop at the next event
    /// boundary in time to report back, and the remainder is picked up by a later run.
    static func run(budgetSeconds: TimeInterval? = nil) async -> UIBackgroundFetchResult {
        let service = ContentUpdateService.shared
        guard !service.isUpdating else {
            log("🔄 BG sync: atualização já em andamento, pulando")
            return .noData
        }

        var budgetTask: Task<Void, Never>?
        if let budgetSeconds {
            budgetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(budgetSeconds))
                guard !Task.isCancelled else { return }
                log("🔄 BG sync: orçamento de \(Int(budgetSeconds)) s esgotado, interrompendo")
                BackgroundSyncMetrics.record("sync_budget_exhausted(\(service.processedUpdateNumber)/\(service.totalUpdateCount))")
                service.cancelCurrentUpdate()
            }
        }
        defer { budgetTask?.cancel() }

        log("🔄 BG sync: iniciando atualização de conteúdo")
        let didUpdate = await service.update()
        log("🔄 BG sync: terminou com status \(service.lastUpdateStatus), processou \(service.processedUpdateNumber) de \(service.totalUpdateCount) eventos")

        guard service.lastUpdateStatus == .done else { return .failed }

        if didUpdate {
            didUpdateInBackground = true
        }
        return didUpdate ? .newData : .noData
    }

    private static func handle(_ task: BGAppRefreshTask) {
        log("⏰ BGAppRefresh: sistema acordou o app para atualizar")
        scheduleRefresh() // Keep the chain going for the next opportunity.

        let updateTask = Task { @MainActor in
            let result = await run()
            log("⏰ BGAppRefresh: concluído: \(result.debugLabel)")
            let service = ContentUpdateService.shared
            BackgroundSyncMetrics.record("refresh_sync(\(result.debugLabel), \(service.processedUpdateNumber)/\(service.totalUpdateCount))")
            task.setTaskCompleted(success: result != .failed)
        }

        // If time runs out, cancellation makes the update loop stop at the next event;
        // unfinished events stay marked unsuccessful and are retried on the next run.
        task.expirationHandler = {
            log("⏰ BGAppRefresh: tempo esgotado, cancelando")
            updateTask.cancel()
        }
    }
}

extension UIBackgroundFetchResult {

    var debugLabel: String {
        switch self {
        case .newData: return "novidades baixadas"
        case .noData: return "sem novidades"
        case .failed: return "falhou"
        @unknown default: return "desconhecido (\(rawValue))"
        }
    }
}
