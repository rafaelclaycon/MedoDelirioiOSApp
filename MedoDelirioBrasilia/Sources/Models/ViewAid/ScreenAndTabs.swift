//
//  ScreenAndTabs.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 13/10/22.
//

import Foundation

enum PadScreen: Int {

    case allSounds, favorites, groupedByAuthor, reactions, songs, trends, settings, allFolders, specificFolder
}

enum PhoneTab: Int {

    case sounds, reactions, episodes, settings, search
}

/// What's selected in the iPad and Mac sidebar. Separate from `PadScreen`, which
/// predates the sidebar and has no room for episodes or for each user folder.
enum SidebarTab: Hashable {

    case sounds, favorites, reactions, authors, episodes, allFolders, search
    case folder(id: String)
    /// The placeholder row shown while folders load, or when they fail to.
    case folderStatus

    /// The sidebar item for a tab bar destination. The Vírgulas sections the tab bar
    /// shows inside one tab each have their own item here; Músicas has none, so it
    /// lands on Vírgulas.
    init?(_ tab: PhoneTab, soundsMode: ContentModeOption? = nil) {
        switch tab {
        case .sounds:
            switch soundsMode {
            case .favorites: self = .favorites
            case .folders: self = .allFolders
            case .authors: self = .authors
            case .all, .songs, nil: self = .sounds
            }
        case .reactions: self = .reactions
        case .episodes: self = .episodes
        case .search: self = .search
        // A sheet in the sidebar layout, not a destination.
        case .settings: return nil
        }
    }

    /// The sidebar item for a `PadScreen`, which Trends still uses to send you to a
    /// sound or a reaction.
    init?(_ screen: PadScreen) {
        switch screen {
        case .allSounds: self = .sounds
        case .favorites: self = .favorites
        case .groupedByAuthor: self = .authors
        case .reactions: self = .reactions
        case .trends: self = .search
        case .allFolders, .specificFolder: self = .allFolders
        case .songs, .settings: return nil
        }
    }
}
