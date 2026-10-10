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
}
