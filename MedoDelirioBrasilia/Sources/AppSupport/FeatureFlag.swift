//
//  FeatureFlag.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum FeatureFlag: String, CaseIterable {

    case snowLeopard = "featureFlag_snowLeopard"
    case retrospective = "featureFlag_retrospective"

    var displayName: String {
        switch self {
        case .snowLeopard:
            return "Snow Leopard"
        case .retrospective:
            return "Retrospectiva 2026"
        }
    }

    var description: String {
        switch self {
        case .snowLeopard:
            return "Destaque de episódio popular na tela de sugestões de busca."
        case .retrospective:
            return "Banner da Retrospectiva no topo de Vírgulas."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
