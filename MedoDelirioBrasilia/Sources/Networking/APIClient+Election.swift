//
//  APIClient+Election.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/09/26.
//

import Foundation

/// What the server knows about the live President count.
struct ElectionLiveInfo: Codable {

    /// Remote switch for the whole feature.
    let enabled: Bool
    /// APNs broadcast channel the Live Activity subscribes to. Beta and production have
    /// different channels, hence the bundle ID in the request.
    let channelId: String?
    let round: Int
    /// Nil before the first TSE file is available.
    let state: ElectionActivityAttributes.ContentState?
}

extension APIClient {

    func electionLiveInfo() async throws -> ElectionLiveInfo {
        var components = URLComponents(string: serverPath + "v4/election/live")!
        if let bundleId = Bundle.main.bundleIdentifier {
            components.queryItems = [URLQueryItem(name: "bundleId", value: bundleId)]
        }
        return try await get(from: components.url!)
    }
}
