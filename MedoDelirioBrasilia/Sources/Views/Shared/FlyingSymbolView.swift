//
//  FlyingSymbolView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 17/01/26.
//

import SwiftUI

struct FlyingSymbolView: View {
    let symbol: String
    let angle: Double
    let delay: Double

    private let cycleDuration: Double = 14.0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let adjustedTime = elapsed - delay
            let progress = adjustedTime > 0
                ? CGFloat((adjustedTime.truncatingRemainder(dividingBy: cycleDuration)) / cycleDuration)
                : 0

            // Gentle scale: start tiny, end moderately larger
            let scale = 0.15 + (progress * 1.8)
            let radians = angle * .pi / 180
            // Drift outward slowly
            let distance = progress * 180

            let opacity: Double = {
                // Fade in gently, stay visible longer, fade out smoothly
                if progress < 0.2 {
                    return Double(progress) * 2.25
                } else if progress > 0.8 {
                    return Double(1 - progress) * 2.25
                }
                return 0.45
            }()

            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(opacity))
                .shadow(color: .white.opacity(0.5), radius: 4)
                .scaleEffect(scale)
                .offset(
                    x: cos(radians) * distance,
                    y: sin(radians) * distance
                )
        }
    }
}
