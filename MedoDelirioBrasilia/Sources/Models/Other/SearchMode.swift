//
//  SearchMode.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 22/03/26.
//

import Foundation

enum SearchMode: CaseIterable, FilterOption {

    case virgulas, episodios

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .virgulas:
            "VÍRGULAS"
        case .episodios:
            "EPISÓDIOS"
        }
    }

    var symbol: String {
        switch self {
        case .virgulas:
            "quote.bubble.fill"
        case .episodios:
            "radio.fill"
        }
    }
}
