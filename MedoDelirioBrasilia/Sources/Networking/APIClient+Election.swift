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
    /// How the results screen dresses the final result, from the server's final message. A
    /// plain string so a value this version doesn't know is ignored instead of failing the
    /// whole response; see `theme`.
    let finalTheme: String?

    /// The TSE's own Resultados app on the App Store.
    static let defaultOfficialResultsURL = URL(string: "https://apps.apple.com/br/app/resultados/id1136359313")!

    var officialResults: URL {
        officialResultsURL.flatMap(URL.init(string:)) ?? Self.defaultOfficialResultsURL
    }

    /// Only on the final result.
    var theme: ElectionFinalTheme? {
        guard state?.isFinal == true else { return nil }
        return finalTheme.flatMap(ElectionFinalTheme.init(rawValue:))
    }
}

/// What the results screen shows beyond the Live Activity. Never in a push.
struct ElectionLiveDetails: Codable {

    let sectionsCounted: Int
    let sectionsTotal: Int
    let validVotes: Int
    /// Every candidate in the TSE ranking.
    let candidates: [Candidate]
    /// Blank and null votes and who didn't vote, for the sections counted so far. Nil from
    /// servers older than it, or when the TSE file doesn't have them.
    let turnout: Turnout?

    struct Turnout: Codable {
        let electorate: Int
        let attended: Int
        let abstentions: Int
        /// Of the voters in counted sections, 0 to 100.
        let abstentionPercent: Double
        let totalVotes: Int
        let blankVotes: Int
        /// Of every vote cast, 0 to 100.
        let blankPercent: Double
        let nullVotes: Int
        let nullPercent: Double
    }

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

    /// `bundleId` picks the broadcast channel. `appVersion` lets the server show the feature
    /// to the version in App Review while the one in the store stays without it.
    func electionLiveInfo() async throws -> ElectionLiveInfo {
        var components = URLComponents(string: APIConfig.electionAPIURL + "v4/election/live")!
        var queryItems: [URLQueryItem] = []
        if let bundleId = Bundle.main.bundleIdentifier {
            queryItems.append(URLQueryItem(name: "bundleId", value: bundleId))
        }
        if !Versioneer.appVersion.isEmpty {
            queryItems.append(URLQueryItem(name: "appVersion", value: Versioneer.appVersion))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return try await get(from: components.url!)
    }
}
