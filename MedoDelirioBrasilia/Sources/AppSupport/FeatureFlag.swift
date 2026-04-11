//
//  FeatureFlag.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import Foundation

enum FeatureFlag: String, CaseIterable {

    case projectSidecast = "featureFlag_projectSidecast"
    case projectGravity = "featureFlag_projectGravity"
    case projectFirula = "featureFlag_projectFirula"

    var displayName: String {
        switch self {
        case .projectSidecast:
            return "Project Sidecast"
        case .projectGravity:
            return "Project Gravity"
        case .projectFirula:
            return "Project Firula"
        }
    }

    var description: String {
        switch self {
        case .projectSidecast:
            return "Gere clipes compartilháveis a partir de episódios do podcast."
        case .projectGravity:
            return "Busca aproximada e ranqueada por relevância na aba Vírgulas."
        case .projectFirula:
            return "Telas e recursos de comemoração do 4º aniversário do app."
        }
    }

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        UserDefaults.standard.bool(forKey: flag.rawValue)
    }

    static func setEnabled(_ flag: FeatureFlag, to value: Bool) {
        UserDefaults.standard.set(value, forKey: flag.rawValue)
    }
}
