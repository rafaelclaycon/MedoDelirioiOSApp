//
//  TopPlayedItem.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import Foundation

/// One row of the most played sounds or songs, as the server sends it. Plays started
/// by a playlist advancing on its own aren't counted.
struct TopPlayedItem: Codable, Equatable {

    let contentId: String
    let contentName: String
    let contentAuthorId: String
    /// The music genre for songs.
    let contentAuthorName: String
    let playCount: Int
    let uniqueListeners: Int
}
