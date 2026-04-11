//
//  AppIcon.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/08/22.
//

import UIKit

/// The alternate app icons available for this app to use.
///
/// These raw values match the names in the app's project settings under
/// `ASSETCATALOG_COMPILER_APPICON_NAME` and `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
enum Icon: String, CaseIterable, Identifiable {

    case primary              = "AppIcon"
    case odioNojo             = "AppIcon-OdioNojo"
    case bomDiaBoaTarde       = "AppIcon-BomDiaBoaTarde"
    case medoDelicia          = "AppIcon-MedoDelicia"
    case lgbt                 = "AppIcon-LGBT"
    case birthday             = "AppIcon-Birthday"

    var id: String { self.rawValue }

    var imageNameForInsideTheApp: String {
        switch self {
        case .primary:
            return "IconePadrao"
        case .odioNojo:
            return "IconeOdioNojo"
        case .bomDiaBoaTarde:
            return "IconeBomDiaBoaTarde"
        case .medoDelicia:
            return "IconeMedoDelicia"
        case .lgbt:
            return "IconeLGBT"
        case .birthday:
            return "IconeAniversario"
        }
    }

    var marketingName: String {
        switch self {
        case .primary:
            return "Padrão"
        case .odioNojo:
            return "Ódio e Nojo"
        case .bomDiaBoaTarde:
            return "Bom dia, boa tarde, boa noite... por enquanto"
        case .medoDelicia:
            return "Medo e Delícia"
        case .lgbt:
            return "Orgulho LGBTQIAPN+"
        case .birthday:
            return "Aniversário de 4 Anos"
        }
    }
}

class AppIcon: ObservableObject, Equatable {

    @Published var appIcon: Icon = .primary

    static func == (lhs: AppIcon, rhs: AppIcon) -> Bool {
        return lhs.appIcon == rhs.appIcon
    }

    /// Change the app icon.
    /// - Tag: setAlternateAppIcon
    func setAlternateAppIcon(icon: Icon) {
        // Set the icon name to nil to use the primary icon.
        let iconName: String? = (icon != .primary) ? icon.rawValue : nil

        // Avoid setting the name if the app already uses that icon.
        guard UIApplication.shared.alternateIconName != iconName else { return }

        UIApplication.shared.setAlternateIconName(iconName) { (error) in
            if let error = error {
                print("Failed request to update the app’s icon: \(error)")
            }
        }

        appIcon = icon
    }

    /// Initializes the model with the current state of the app's icon.
    init() {
        let iconName = UIApplication.shared.alternateIconName

        if iconName == nil {
            appIcon = .primary
        } else {
            appIcon = Icon(rawValue: iconName!)!
        }
    }
}
