//
//  IntentProviders.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 04/10/24.
//

import Foundation
import AppIntents

struct PlayRandomSoundIntentProvider: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayRandomSoundIntent(),
            phrases: [
                "Toque uma vírgula do \(.applicationName)",
                "Toque um som do \(.applicationName)",
                "Toque um som aleatório do \(.applicationName)",
                "\(.applicationName)",
            ],
            shortTitle: "Tocar som aleatório",
            systemImageName: "play.fill"
        )
    }
}
