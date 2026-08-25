//
//  BannerRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 30/04/25.
//

import Foundation

protocol BannerRepositoryProtocol {

    func dynamicBanner() async -> DynamicBannerData?
    func promoBanner() async -> PromoBannerData?
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

    /// Returns the promo banner only when it's actually renderable, so the view never has
    /// to deal with a half-filled payload — a missing link would otherwise ship a dead button.
    func promoBanner() async -> PromoBannerData? {
        do {
            let url = URL(string: apiClient.serverPath + "v4/promo-banner")!
            let data: PromoBannerData = try await apiClient.get(from: url)
            guard data.enabled else { return nil }
            if let excludedVersion = data.excludedVersion, currentAppVersion == excludedVersion {
                return nil
            }
            guard data.buttonURL != nil else { return nil }
            guard let buttonTitle = data.buttonTitle, !buttonTitle.isEmpty else { return nil }
            guard !data.paragraphs.isEmpty else { return nil }
            return data
        } catch {
            print("Unable to check or populate the Promo Banner: \(error.localizedDescription)")
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
