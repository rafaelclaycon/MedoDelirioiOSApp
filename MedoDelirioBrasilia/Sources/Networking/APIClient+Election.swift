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
    /// Every candidate, for the results screen. Nil before the first TSE file, or from a
    /// server older than the results screen.
    let details: ElectionLiveDetails?
    /// Where "App do TSE" goes, set on the server so it can change without an app review.
    let officialResultsURL: String?

    /// The TSE's own Resultados app on the App Store.
    static let defaultOfficialResultsURL = URL(string: "https://apps.apple.com/br/app/resultados/id1136359313")!

    var officialResults: URL {
        officialResultsURL.flatMap(URL.init(string:)) ?? Self.defaultOfficialResultsURL
    }
}

/// What the results screen shows beyond the Live Activity. Never in a push.
struct ElectionLiveDetails: Codable {

    let sectionsCounted: Int
    let sectionsTotal: Int
    let validVotes: Int
    /// Every candidate in the TSE ranking.
    let candidates: [Candidate]

    struct Candidate: Codable, Identifiable {
        let number: Int
        let name: String
        let party: String
        let votes: Int
        let percent: Double
        let status: ElectionActivityAttributes.Status
        let colorHex: String?
        /// False for "Anulado" and "Anulado sub judice".
        let hasValidVotes: Bool

        var id: Int { number }
    }
}

extension APIClient {

    func electionLiveInfo() async throws -> ElectionLiveInfo {
        var components = URLComponents(string: APIConfig.electionAPIURL + "v4/election/live")!
        if let bundleId = Bundle.main.bundleIdentifier {
            components.queryItems = [URLQueryItem(name: "bundleId", value: bundleId)]
        }
        return try await get(from: components.url!)
    }
}
