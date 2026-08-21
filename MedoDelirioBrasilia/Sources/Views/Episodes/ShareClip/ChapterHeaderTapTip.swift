//
//  ChapterHeaderTapTip.swift
//  MedoDelirioBrasilia
//

import SwiftUI
import TipKit

/// Shown on the first chapter title in the transcript picker, once, to surface
/// that tapping it auto-selects that chapter (capped at the max clip length).
struct ChapterHeaderTapTip: Tip {

    var title: Text {
        Text("Novidade")
    }

    var message: Text? {
        Text("Toque no título do capítulo para selecionar o trecho inteiro, até o limite de \(SocialVideoLimit.formatted(WaveformView.maxClipLength)).")
    }

    var image: Image? {
        Image(systemName: "text.badge.checkmark")
    }
}
