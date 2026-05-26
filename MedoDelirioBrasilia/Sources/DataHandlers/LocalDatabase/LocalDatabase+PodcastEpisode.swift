//
//  LocalDatabase+PodcastEpisode.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/02/26.
//

import Foundation
import SQLite

private typealias Expression = SQLite.Expression

extension LocalDatabase {

    private enum Columns {
        static let id = Expression<String>("id")
        static let title = Expression<String>("title")
        static let pubDate = Expression<Date>("pubDate")
        static let audioURL = Expression<String>("audioURL")
        static let description = Expression<String?>("description")
        static let imageURL = Expression<String?>("imageURL")
        static let duration = Expression<Double?>("duration")
        static let isExplicit = Expression<Bool>("isExplicit")
    }

    func allPodcastEpisodes() throws -> [PodcastEpisode] {
        let query = podcastEpisodeTable.order(Columns.pubDate.desc)
        return try db.prepare(query).compactMap { row -> PodcastEpisode? in
            guard let audioURL = URL(string: row[Columns.audioURL]) else { return nil }
            return PodcastEpisode(
                id: row[Columns.id],
                title: row[Columns.title],
                pubDate: row[Columns.pubDate],
                audioURL: audioURL,
                description: row[Columns.description],
                imageURL: row[Columns.imageURL].flatMap { URL(string: $0) },
                duration: row[Columns.duration],
                explicit: row[Columns.isExplicit]
            )
        }
    }

    func podcastEpisode(id: String) throws -> PodcastEpisode? {
        let query = podcastEpisodeTable.filter(Columns.id == id).limit(1)
        return try db.prepare(query).compactMap { row -> PodcastEpisode? in
            guard let audioURL = URL(string: row[Columns.audioURL]) else { return nil }
            return PodcastEpisode(
                id: row[Columns.id],
                title: row[Columns.title],
                pubDate: row[Columns.pubDate],
                audioURL: audioURL,
                description: row[Columns.description],
                imageURL: row[Columns.imageURL].flatMap { URL(string: $0) },
                duration: row[Columns.duration],
                explicit: row[Columns.isExplicit]
            )
        }.first
    }

    func upsertPodcastEpisodes(_ episodes: [PodcastEpisode]) throws {
        try db.transaction {
            for episode in episodes {
                try db.run(podcastEpisodeTable.insert(or: .replace,
                    Columns.id <- episode.id,
                    Columns.title <- episode.title,
                    Columns.pubDate <- episode.pubDate,
                    Columns.audioURL <- episode.audioURL.absoluteString,
                    Columns.description <- episode.description,
                    Columns.imageURL <- episode.imageURL?.absoluteString,
                    Columns.duration <- episode.duration,
                    Columns.isExplicit <- episode.explicit
                ))
            }
        }
    }
}
