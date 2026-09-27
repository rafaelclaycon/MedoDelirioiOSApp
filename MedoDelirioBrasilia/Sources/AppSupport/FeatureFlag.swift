//
//  FeatureFlag.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum FeatureFlag: String, CaseIterable {

    case snowLeopard = "featureFlag_snowLeopard"
    case transcriptFullView = "featureFlag_transcriptFullView"

    var displayName: String {
        switch self {
        case .snowLeopard:
            return "Snow Leopard"
        case .transcriptFullView:
            return "Transcript Full View"
        }
    }

    var description: String {
        switch self {
        case .snowLeopard:
            return "Destaque de episódio popular na tela de sugestões de busca."
        case .transcriptFullView:
            return "Abre a transcrição completa e pesquisável a partir da tela do player."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
