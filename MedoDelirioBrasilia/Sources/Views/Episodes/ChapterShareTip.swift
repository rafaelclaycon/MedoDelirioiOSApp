//
//  ChapterShareTip.swift
//  MedoDelirioBrasilia
//

import SwiftUI
import TipKit

/// Shown on the first chapter row in Now Playing, once, to surface the
/// long-press → "Compartilhar Trecho" action added alongside chapters.
struct ChapterShareTip: Tip {

    var title: Text {
        Text("Novidade")
    }

    var message: Text? {
        Text("Segure em um capítulo para compartilhar esse trecho como vídeo.")
    }

    var image: Image? {
        Image(systemName: "scissors")
    }
}
