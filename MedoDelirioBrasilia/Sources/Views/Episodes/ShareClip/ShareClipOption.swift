//
//  ShareClipOption.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/02/26.
//

import CoreGraphics
import Foundation

// MARK: - Share Mode

enum ShareClipShareMode: String, CaseIterable, Identifiable {

    case soundOnly
    case portraitVideo
    case landscapeVideo
    case square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soundOnly: "Somente Áudio"
        case .portraitVideo: "Vídeo Retrato"
        case .landscapeVideo: "Vídeo Paisagem"
        case .square: "Quadrado"
        }
    }

    var symbol: String {
        switch self {
        case .soundOnly: "waveform"
        case .portraitVideo: "rectangle.portrait"
        case .landscapeVideo: "rectangle"
        case .square: "square"
        }
    }

    /// Pixel dimensions for video export. Returns `nil` for audio-only mode.
    var videoSize: CGSize? {
        switch self {
        case .soundOnly: nil
        case .portraitVideo: CGSize(width: 1080, height: 1920)
        case .landscapeVideo: CGSize(width: 1920, height: 1080)
        case .square: CGSize(width: 1080, height: 1080)
        }
    }

    /// All modes that produce a video (excludes audio-only).
    static var videoCases: [ShareClipShareMode] {
        allCases.filter { $0.videoSize != nil }
    }
}

// MARK: - Branding

enum ShareClipBranding: String, CaseIterable, Identifiable {

    case none
    case appBadge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "Sem Selo do App"
        case .appBadge: "Clipe Criado com Medo e Delírio iOS"
        }
    }

    var symbol: String {
        switch self {
        case .none: "rectangle.dashed"
        case .appBadge: "app.badge.checkmark"
        }
    }
}
