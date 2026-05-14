//
//  DynamicBannerData.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 09/05/24.
//

import Foundation

struct DynamicBannerData: Codable {

    let symbol: String
    let title: String
    let text: [String]
    let buttons: [DynamicBannerButton]

    init(
        symbol: String,
        title: String,
        text: [String],
        buttons: [DynamicBannerButton]
    ) {
        self.symbol = symbol
        self.title = title
        self.text = text
        self.buttons = buttons
    }

    init() {
        self.symbol = ""
        self.title = ""
        self.text = []
        self.buttons = []
    }
}

struct DynamicBannerButton: Codable {

    let title: String
    let type: DynamicBannerButtonType
    let data: String
    let additionalData: String?
}

enum DynamicBannerButtonType: String, Codable {

    case copyText, openLink
}

struct AnniversaryBannerData: Codable {

    let enabled: Bool
    let excludedVersion: String
}
