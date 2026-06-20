//
//  FeatureFlag.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum FeatureFlag: String, CaseIterable {

    case projectSidecast = "featureFlag_projectSidecast"
    case snowLeopard = "featureFlag_snowLeopard"
    case transcriptFullView = "featureFlag_transcriptFullView"
    case iPadNowPlayingAccessory = "featureFlag_iPadNowPlayingAccessory"

    var displayName: String {
        switch self {
        case .projectSidecast:
            return "Project Sidecast"
        case .snowLeopard:
            return "Snow Leopard"
        case .transcriptFullView:
            return "Transcript Full View"
        case .iPadNowPlayingAccessory:
            return "iPad Now Playing Accessory"
        }
    }

    var description: String {
        switch self {
        case .projectSidecast:
            return "Gere clipes compartilháveis a partir de episódios do podcast."
        case .snowLeopard:
            return "Destaque de episódio popular na tela de sugestões de busca."
        case .transcriptFullView:
            return "Abre a transcrição completa e pesquisável a partir da tela do player."
        case .iPadNowPlayingAccessory:
            return "Mostra o acessório de reprodução na barra inferior do iPad (em vez da barra flutuante)."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
