//
//  PlayRandomSoundIntent.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/09/24.
//

import AppIntents
import SwiftUI
import WidgetKit

enum URLCreationError: Error {
    case invalidURL
}

struct PlayRandomSoundIntent: AppIntent {

    static let title: LocalizedStringResource = "Tocar som aleatório"

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let url = URL(string: "medodelirio://playrandomsound") else {
            throw URLCreationError.invalidURL
        }
        await MainActor.run {
            EnvironmentValues().openURL(url)
        }
        return .result(opensIntent: OpenURLIntent(url))
    }
}
