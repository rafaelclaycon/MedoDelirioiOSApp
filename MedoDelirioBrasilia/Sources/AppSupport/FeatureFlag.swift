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
    case electionLiveActivity = "featureFlag_electionLiveActivity"

    var displayName: String {
        switch self {
        case .snowLeopard:
            return "Snow Leopard"
        case .transcriptFullView:
            return "Transcript Full View"
        case .electionLiveActivity:
            return "Election Live Activity"
        }
    }

    var description: String {
        switch self {
        case .snowLeopard:
            return "Destaque de episódio popular na tela de sugestões de busca."
        case .transcriptFullView:
            return "Abre a transcrição completa e pesquisável a partir da tela do player."
        case .electionLiveActivity:
            return "Libera a Atividade ao Vivo da apuração mesmo com o servidor desligado. Para testar no simulado do TSE."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
