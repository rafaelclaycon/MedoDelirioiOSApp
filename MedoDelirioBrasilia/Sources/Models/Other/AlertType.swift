//
//  AlertType.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import Foundation

// MARK: - Playable Content

enum PlayableContentAlert: Identifiable {

    case contentFileNotFound
    case issueSharingContent
    case unableToRedownloadContent

    var id: String {
        switch self {
        case .contentFileNotFound: return "contentFileNotFound"
        case .issueSharingContent: return "issueSharingContent"
        case .unableToRedownloadContent: return "unableToRedownloadContent"
        }
    }
}

enum PlayableContentSheet: Identifiable, Equatable {

    case shareAsVideo(AnyEquatableMedoContent)
    case addToFolder([AnyEquatableMedoContent])
    case contentDetail(AnyEquatableMedoContent)

    var id: String {
        switch self {
        case .shareAsVideo(let content): return "shareAsVideo-\(content.id)"
        case .addToFolder(let contents): return "addToFolder-\(contents.map { $0.id }.joined(separator: ","))"
        case .contentDetail(let content): return "contentDetail-\(content.id)"
        }
    }
}

enum ContentGridAlert {

    case issueExportingManySounds
    case removeSingleContent
    case removeMultipleContent
    case issueRemovingContentFromFolder
}

enum AuthorDetailAlertType {

    case ok, reportSoundIssue, askForNewSound
}

enum FolderDetailAlertType {

    case ok, removeSingleSound, removeMultipleSounds
}

enum SongsViewAlert {

    case ok, songUnavailable, redownloadSong
}

enum AddToFolderAlertType {

    case ok, addOnlyNonOverlapping
}
