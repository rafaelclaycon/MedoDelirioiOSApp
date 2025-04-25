//
//  EpisodeRepository.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/12/24.
//

import Foundation
import FeedKit

protocol EpisodeRepositoryProtocol {

    func latestEpisodes() async throws -> [Episode]
    func localUrl(for episode: Episode) async throws -> URL
}

final class EpisodeRepository: EpisodeRepositoryProtocol {

    private let apiClient: NetworkRabbitProtocol

    init(
        apiClient: NetworkRabbitProtocol = NetworkRabbit(serverPath: APIConfig.apiURL)
    ) {
        self.apiClient = apiClient
    }

    func latestEpisodes() async throws -> [Episode] {
        let url = URL(string: "https://www.central3.com.br/category/podcasts/medo-e-delirio/feed/podcast/")!
        let parser = FeedParser(URL: url)

        let result = await withCheckedContinuation { continuation in
            parser.parseAsync { result in
                continuation.resume(returning: result)
            }
        }

        switch result {
        case let .success(feed):
            guard let feed = feed.rssFeed else {
                throw EpisodeRepositoryError.notAnRSSFeed
            }
            guard let items = feed.items else {
                throw EpisodeRepositoryError.emptyFeed
            }

            // podcast.artworkUrl = feed.iTunes?.iTunesImage?.attributes?.href ?? feed.image?.url ?? .empty

//            if podcast.artworkUrl.isEmpty == false, podcast.artworkUrl.contains("https") == false {
//                do {
//                    podcast.artworkUrl = try LinkWizard.fixURLfromHTTPToHTTPS(podcast.artworkUrl)
//                } catch {
//                    print("Failed to correct artwork link for \(podcast.title). URL: \(podcast.artworkUrl) Error: \(error.localizedDescription)")
//                }
//            }

            //podcast.lastCheckDate = Date()

            return items.prefix(10).map { item in
                Episode(
                    episodeId: item.guid?.value ?? UUID().uuidString,
                    title: item.title ?? "SEM TÍTULO",
                    description: item.iTunes?.iTunesSubtitle,
                    pubDate: item.pubDate,
                    duration: item.iTunes?.iTunesDuration ?? 0,
                    creationDate: .now,
                    remoteUrl: URL(string: item.enclosure?.attributes?.url ?? "")
                )
            }

        case .failure(_):
            throw EpisodeRepositoryError.unableToAccessRSSFeed
        }
    }

    func localUrl(for episode: Episode) async throws -> URL {
        guard let remoteUrl = episode.remoteUrl else { throw EpisodeRepositoryError.episodeRemoteUrlNotSet }

        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderUrl = documentsUrl.appendingPathComponent(InternalFolderNames.downloadedEpisodes)

        let preexistingLocal = folderUrl.appendingPathComponent("\(episode.id).mp3")
        if fileManager.fileExists(atPath: preexistingLocal.path) {
            return preexistingLocal
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderUrl.path, isDirectory: &isDirectory) else {
            throw EpisodeRepositoryError.downloadedEpisodesFolderNotFound
        }

        let (tempFile, response) = try await URLSession.shared.download(from: remoteUrl)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw EpisodeRepositoryError.invalidServerResponse
        }

        let destinationUrl = documentsUrl.appendingPathComponent(InternalFolderNames.downloadedEpisodes + "\(episode.id).mp3")

        try fileManager.moveItem(at: tempFile, to: destinationUrl)

        return destinationUrl
    }
}

enum EpisodeRepositoryError: Error {

    case notAnRSSFeed
    case emptyFeed
    case unableToAccessRSSFeed
    case episodeRemoteUrlNotSet
    case downloadedEpisodesFolderNotFound
    case invalidServerResponse
}
