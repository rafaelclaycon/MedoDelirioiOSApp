//
//  BannerRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 30/04/25.
//

import Foundation

protocol BannerRepositoryProtocol {

    func dynamicBanner() async -> DynamicBannerData?
    func showAnniversaryBanner() async -> Bool
}

final class BannerRepository: BannerRepositoryProtocol {

    private let apiClient: APIClientProtocol
    private let currentAppVersion: String

    // MARK: - Initializer

    init(
        apiClient: APIClientProtocol = APIClient(serverPath: APIConfig.apiURL),
        currentAppVersion: String = Versioneer.appVersion
    ) {
        self.apiClient = apiClient
        self.currentAppVersion = currentAppVersion
    }

    func dynamicBanner() async -> DynamicBannerData? {
        do {
            let url = URL(string: apiClient.serverPath + "v4/dynamic-banner-dont-show-version")!
            guard let blockedVersion = try await apiClient.getString(from: url) else {
                return nil
            }
            guard currentAppVersion != blockedVersion else { return nil }
            let dataUrl = URL(string: apiClient.serverPath + "v4/dynamic-banner")!
            return try await apiClient.get(from: dataUrl)
        } catch {
            print("Unable to check or populate the Dynamic Banner: \(error.localizedDescription)")
            return nil
        }
    }

    func showAnniversaryBanner() async -> Bool {
        do {
            let dataUrl = URL(string: apiClient.serverPath + "v4/anniversary-banner")!
            let data: AnniversaryBannerData = try await apiClient.get(from: dataUrl)
            guard data.enabled else { return false }
            return currentAppVersion != data.excludedVersion
        } catch {
            print("Unable to check for the Anniversary Banner: \(error.localizedDescription)")
            return false
        }
    }
}
