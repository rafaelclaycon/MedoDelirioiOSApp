//
//  EpisodeHighlightStore.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/10/26.
//

import Foundation

/// The one episode the server says to dress up in the Episodes list, like the one about
/// Lula's win, set with `POST v4/episode-highlight/:password`. Purely decorative: no
/// highlight, a failed request or a style this version doesn't know all leave the list as
/// it is.
@Observable
final class EpisodeHighlightStore {

    /// The looks this version knows how to draw. The server checks new ones against its own
    /// list, so a newer style just shows nothing here.
    enum Style: String {
        case lulaWin
    }

    struct Highlight: Equatable {
        let episodeId: String
        let style: Style
        /// The badge's text, from the server. No badge when it sends none, or an empty one.
        let label: String?
    }

    @ObservationIgnored private let apiClient: APIClientProtocol
    @ObservationIgnored private var hasLoaded = false

    private(set) var highlight: Highlight?

    init(apiClient: APIClientProtocol = APIClient.shared) {
        self.apiClient = apiClient
    }

    func highlight(for episodeId: String) -> Highlight? {
        highlight?.episodeId == episodeId ? highlight : nil
    }

    /// Once per launch.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    /// Pull to refresh asks again, so a highlight set while the app is open shows up, and one
    /// taken off goes away.
    func reload() async {
        guard let url = URL(string: apiClient.serverPath + "v4/episode-highlight") else { return }
        do {
            let response: HighlightResponse = try await apiClient.get(from: url)
            highlight = Style(rawValue: response.style).map {
                Highlight(episodeId: response.episodeId, style: $0, label: Self.badgeText(response.label))
            }
        } catch {
            // A 404 means nothing is highlighted; anything else, keep what's there.
            if case .resourceNotFound? = error as? APIClientError {
                highlight = nil
            }
        }
    }
}

// MARK: - Server Response

extension EpisodeHighlightStore {

    private struct HighlightResponse: Codable {
        let episodeId: String
        let style: String
        let label: String?
    }

    /// Blank reads as no badge.
    private static func badgeText(_ label: String?) -> String? {
        guard let label = label?.trimmingCharacters(in: .whitespaces), !label.isEmpty else { return nil }
        return label
    }
}
