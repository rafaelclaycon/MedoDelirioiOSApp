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
    case episodePillControls = "featureFlag_episodePillControls"

    var displayName: String {
        switch self {
        case .projectSidecast:
            return "Project Sidecast"
        case .snowLeopard:
            return "Snow Leopard"
        case .episodePillControls:
            return "Episode Pill Controls"
        }
    }

    var description: String {
        switch self {
        case .projectSidecast:
            return "Gere clipes compartilháveis a partir de episódios do podcast."
        case .snowLeopard:
            return "Destaque de episódio popular na tela de sugestões de busca."
        case .episodePillControls:
            return "Exibe os controles de reprodução como uma pílula horizontal abaixo da descrição do episódio."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
