//
//  ContentModeOption.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 29/03/25.
//

import Foundation

enum ContentModeOption: CaseIterable, FilterOption {

    case all, favorites, songs, folders, authors

    var id: String {
        displayName
    }

    var displayName: String {
        switch self {
        case .all:
            "Todas"
        case .favorites:
            "Favoritas"
        case .songs:
            "Músicas"
        case .folders:
            "Pastas"
        case .authors:
            "Autores"
        }
    }

    var symbol: String {
        switch self {
        case .all:
            "quote.opening"
        case .favorites:
            "heart.fill"
        case .songs:
            "music.quarternote.3"
        case .folders:
            "folder.fill"
        case .authors:
            "person.3.sequence.fill"
        }
    }
}
