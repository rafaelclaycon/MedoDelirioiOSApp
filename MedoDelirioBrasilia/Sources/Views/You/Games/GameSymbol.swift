//
//  GameSymbol.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import SwiftUI

/// A game's symbol where it stands out (entry card, card backs, result, shared picture):
/// its emoji when it has one, drawn as is in its own colors, otherwise its SF Symbol in
/// `style`. Faint watermarks keep the SF Symbol, which tints to white.
struct GameSymbol<Style: ShapeStyle>: View {

    let kind: GameKind
    /// The SF Symbol's point size. An emoji is drawn a little larger, since it fills less
    /// of its box.
    let size: CGFloat
    let style: Style

    var body: some View {
        if let emoji = kind.emoji {
            Text(emoji)
                .font(.system(size: size * 1.15))
                .accessibilityHidden(true)
        } else {
            Image(systemName: kind.systemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(style)
                .accessibilityHidden(true)
        }
    }
}
