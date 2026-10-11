//
//  TopEpisodeItem.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation

/// One row of the most listened episodes, as the server sends it. Counts only plays in
/// this app, not on Spotify or other podcast platforms.
struct TopEpisodeItem: Codable, Equatable {

    let episodeId: String
    let episodeName: String
    let playCount: Int
    let uniqueListeners: Int
}
