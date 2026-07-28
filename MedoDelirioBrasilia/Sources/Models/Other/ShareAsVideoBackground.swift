//
//  ShareAsVideoBackground.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/07/26.
//

import SwiftUI

enum ShareAsVideoBackground: String, CaseIterable, Identifiable, Equatable {

    case green
    case red

    var id: String { rawValue }

    var imageName: String {
        switch self {
        case .green:
            return "square_video_background_green"
        case .red:
            return "square_video_background_red"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .green:
            return [Color(red: 0.09, green: 0.35, blue: 0.08), Color(red: 0.11, green: 0.75, blue: 0.32)]
        case .red:
            return [Color(red: 0.66, green: 0.11, blue: 0.13), Color(red: 0.85, green: 0.22, blue: 0.18)]
        }
    }
}
