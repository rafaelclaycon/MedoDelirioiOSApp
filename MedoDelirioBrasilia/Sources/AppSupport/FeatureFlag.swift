//
//  FeatureFlag.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum FeatureFlag: String, CaseIterable {

    case episodeNotifications = "featureFlag_episodeNotifications"
    case projectSidecast = "featureFlag_projectSidecast"
    case projectEleDisseIssoMesmo = "featureFlag_projectEleDisseIssoMesmo"

    var displayName: String {
        switch self {
        case .episodeNotifications:
            return "Project Echo"
        case .projectSidecast:
            return "Project Sidecast"
        case .projectEleDisseIssoMesmo:
            return "Project Ele Disse Isso Mesmo?"
        }
    }

    var description: String {
        switch self {
        case .episodeNotifications:
            return "Receber notificações quando novos episódios forem publicados."
        case .projectSidecast:
            return "Gere clipes compartilháveis a partir de episódios do podcast."
        case .projectEleDisseIssoMesmo:
            return "Transcrições dos episódios com legendas em tempo real e busca por texto."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
