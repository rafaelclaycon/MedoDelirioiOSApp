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
    func showRetroBanner() async -> Bool?
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

    /// Whether it shows is up to `DonationGate`, like every other ask.
    func dynamicBanner() async -> DynamicBannerData? {
        do {
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

    /// Whether this version may show the Retrospectiva banner, set with
    /// `POST v4/retro-banner/:password` (`{"enabled": true, "minimumVersion": "13.9"}`). The
    /// server does the version check, so moving the minimum up needs no app update. Nil when
    /// the request fails.
    func showRetroBanner() async -> Bool? {
        var components = URLComponents(string: apiClient.serverPath + "v4/retro-banner")
        components?.queryItems = [URLQueryItem(name: "appVersion", value: currentAppVersion)]
        guard let url = components?.url else { return nil }
        do {
            let response: RetroBannerVisibility = try await apiClient.get(from: url)
            return response.show
        } catch {
            print("Unable to check for the Retro Banner: \(error.localizedDescription)")
            return nil
        }
    }
}

private struct RetroBannerVisibility: Codable {
    let show: Bool
}
