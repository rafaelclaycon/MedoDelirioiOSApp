//
//  Episode.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/10/22.
//

import Foundation

struct Episode: Hashable, Codable, Identifiable {

    let id: String
    var episodeId: String
    var title: String
    var description: String?
    var pubDate: Date?
    var duration: Double
    var creationDate: Date
    var remoteUrl: URL?
    var localUrl: URL?
//    var spotifyLink: String
//    var applePodcastsLink: String
//    var pocketCastsLink: String
    
    init(
        id: String = UUID().uuidString,
        episodeId: String,
        title: String,
        description: String?,
        pubDate: Date?,
        duration: Double,
        creationDate: Date,
        remoteUrl: URL? = nil,
        localUrl: URL? = nil
//        spotifyLink: String = .empty,
//        applePodcastsLink: String = .empty,
//        pocketCastsLink: String = .empty
    ) {
        self.id = id
        self.episodeId = episodeId
        self.title = title
        self.description = description
        self.pubDate = pubDate
        self.duration = duration
        self.creationDate = creationDate
        self.remoteUrl = remoteUrl
        self.localUrl = localUrl
//        self.spotifyLink = spotifyLink
//        self.applePodcastsLink = applePodcastsLink
//        self.pocketCastsLink = pocketCastsLink
    }
}

enum SortOption {

    case fromNewToOld, fromOldToNew
}

