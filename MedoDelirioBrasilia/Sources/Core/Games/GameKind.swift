//
//  GameKind.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI

/// The games in Você. The raw value keys the best score, so it must not change.
enum GameKind: String, CaseIterable, Identifiable {

    /// A photo; pick whose face it is.
    case whoseFace
    /// A sound; pick whose voice it is.
    case whoseVoice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whoseFace: "De quem é essa fuça?"
        case .whoseVoice: "Eu já ouvi essa voz antes…"
        }
    }

    var subtitle: String {
        switch self {
        case .whoseFace: "Adivinhe pela foto"
        case .whoseVoice: "Adivinhe pela voz"
        }
    }

    var question: String {
        switch self {
        case .whoseFace: "Quem é?"
        case .whoseVoice: "De quem é essa voz?"
        }
    }

    var systemImage: String {
        switch self {
        case .whoseFace: "eyes"
        case .whoseVoice: "waveform"
        }
    }

    /// The card's mesh, three by three. Fuça in the flag's green and yellow, Voz in its
    /// blue running into teal. The light end sits top right, away from the title and
    /// the score, so white text stays readable.
    var meshColors: [Color] {
        switch self {
        case .whoseFace:
            let deepGreen = Color(red: 0.01, green: 0.36, blue: 0.16)
            return [
                deepGreen, .darkerGreen, .brightYellow,
                deepGreen, .darkerGreen, .brightGreen,
                .darkestGreen, deepGreen, .darkerGreen
            ]
        case .whoseVoice:
            let lightTeal = Color(red: 0.20, green: 0.78, blue: 0.70)
            let blue = Color(red: 0.10, green: 0.35, blue: 0.75)
            let deepNavy = Color(red: 0.03, green: 0.10, blue: 0.25)
            return [
                .mutedNavyBlue, blue, lightTeal,
                .mutedNavyBlue, blue, .teal,
                deepNavy, .mutedNavyBlue, blue
            ]
        }
    }

    /// For symbols and highlights that sit on a plain background.
    var accentColor: Color {
        switch self {
        case .whoseFace: .darkerGreen
        case .whoseVoice: Color(red: 0.10, green: 0.35, blue: 0.75)
        }
    }
}
