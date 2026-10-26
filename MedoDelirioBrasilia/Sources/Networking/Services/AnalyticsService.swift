//
//  Analytics.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/11/23.
//

import UIKit

protocol AnalyticsServiceProtocol {

    func send(originatingScreen: String, action: String) async
    func send(currentScreen: String, folderName: String, action: String) async
}

final class AnalyticsService: AnalyticsServiceProtocol {

    private let apiClient: APIClientProtocol

    // MARK: - Initializer

    init(
        apiClient: APIClientProtocol = APIClient.shared
    ) {
        self.apiClient = apiClient
    }

    /// Every event is also left as a crash breadcrumb (`Breadcrumbs`).
    func send(
        originatingScreen: String = "",
        action: String
    ) async {
        Breadcrumbs.leave(originatingScreen.isEmpty ? action : "\(originatingScreen): \(action)")
        do {
            let usageMetric = await UsageMetric(
                customInstallId: AppPersistentMemory.shared.customInstallId,
                originatingScreen: originatingScreen,
                destinationScreen: action,
                systemName: UIDevice.current.systemName,
                isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac,
                appVersion: Versioneer.appVersion,
                dateTime: Date.now.iso8601withFractionalSeconds,
                currentTimeZone: TimeZone.current.abbreviation() ?? ""
            )
            let url = URL(string: apiClient.serverPath + "v2/usage-metric")!
            try await apiClient.post(to: url, body: usageMetric)
        } catch {
            print("Error sending analytics: \(error.localizedDescription)")
        }
    }

    func send(
        currentScreen: String,
        folderName: String,
        action: String
    ) async {
        // Without the folder's name: people name their own folders.
        Breadcrumbs.leave("\(currentScreen): \(action)")
        do {
            let usageMetric = UsageMetric(
                customInstallId: AppPersistentMemory.shared.customInstallId,
                originatingScreen: "\(currentScreen)(\(folderName))",
                destinationScreen: action,
                systemName: await UIDevice.current.systemName,
                isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac,
                appVersion: Versioneer.appVersion,
                dateTime: Date.now.iso8601withFractionalSeconds,
                currentTimeZone: TimeZone.current.abbreviation() ?? ""
            )
            let url = URL(string: apiClient.serverPath + "v2/usage-metric")!
            try await apiClient.post(to: url, body: usageMetric)
        } catch {
            print("Error sending analytics: \(error.localizedDescription)")
        }
    }
}
