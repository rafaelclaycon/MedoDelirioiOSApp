//
//  StarsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 17/01/26.
//

import SwiftUI

struct StarsView: View {
    let colorScheme: ColorScheme

    // Fixed positions for consistency
    private let particles: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = [
        (-120, -80, 2, 0.8), (80, -100, 1.5, 0.6), (150, -60, 2.5, 0.7),
        (-80, -40, 1, 0.5), (100, 20, 2, 0.6), (-140, 30, 1.5, 0.7),
        (60, -120, 1, 0.4), (-50, 60, 2, 0.5), (130, 80, 1.5, 0.6),
        (-100, 100, 1, 0.4), (40, 50, 2.5, 0.3), (-160, -20, 1, 0.5),
        (170, -30, 1.5, 0.4), (-30, -90, 2, 0.6), (90, 110, 1, 0.3),
        (-150, 70, 2, 0.5), (20, -50, 1.5, 0.4), (110, -90, 1, 0.5),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(particles.enumerated()), id: \.offset) { _, particle in
                Circle()
                    .fill(particleColor.opacity(particle.opacity * opacityMultiplier))
                    .frame(width: particle.size * sizeMultiplier, height: particle.size * sizeMultiplier)
                    .offset(x: particle.x, y: particle.y)
            }
        }
    }

    private var particleColor: Color {
        colorScheme == .dark ? .white : .white
    }

    private var opacityMultiplier: Double {
        colorScheme == .dark ? 1.0 : 0.7
    }

    private var sizeMultiplier: CGFloat {
        colorScheme == .dark ? 1.0 : 1.5  // Slightly larger "clouds" in light mode
    }
}
