//
//  EpisodePlaybackStateFilter.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum EpisodePlaybackStateFilter: String, CaseIterable {

    case notStarted, started, finished

    var displayName: String {
        switch self {
        case .notStarted: "Não Iniciados"
        case .started: "Em Andamento"
        case .finished: "Finalizados"
        }
    }

    var systemImage: String {
        switch self {
        case .notStarted: "circle"
        case .started: "play.circle"
        case .finished: "checkmark.circle"
        }
    }

    static var allSet: Set<EpisodePlaybackStateFilter> {
        Set(allCases)
    }
}
