//
//  IntroducingUniversalSearchView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 17/01/26.
//

import SwiftUI

struct IntroducingUniversalSearchView: View {

    let appMemory: AppPersistentMemoryProtocol

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var glowAnimation = false
    @State private var pulseAnimation = false
    @State private var ringAnimation = false

    private var hasHomeIndicator: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return false
        }
        return window.safeAreaInsets.bottom > 0
    }

    private var currentOSName: String {
        "\(UIDevice.systemMarketingName) 26"
    }

    private var searchButtonPlacement: String {
        if UIDevice.deviceType == .iPhone {
            return "botão dedicado no canto inferior direito"
        } else {
            return "botão dedicado na barra lateral"
        }
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.05, green: 0.05, blue: 0.15),  // Deep space black-blue
                Color(red: 0.1, green: 0.08, blue: 0.25),   // Dark purple
                Color(red: 0.15, green: 0.12, blue: 0.35)   // Subtle cosmic purple
            ]
        } else {
            return [
                Color(red: 0.1, green: 0.4, blue: 0.9),     // Bright blue
                Color(red: 0.2, green: 0.6, blue: 1.0),     // Sky blue
                Color(red: 0.4, green: 0.7, blue: 1.0)      // Light blue
            ]
        }
    }

    private let flyingSymbols: [(symbol: String, angle: Double, delay: Double)] = [
        // Spread evenly around 360°, staggered delays for continuous stream
        ("headphones", 0, 0.0),
        ("music.quarternote.3", 45, 1.1),
        ("person.2", 90, 2.2),
        ("folder", 135, 3.3),
        ("theatermasks", 180, 4.4),
        ("waveform", 225, 5.5),
        ("headphones", 270, 6.6),
        ("music.quarternote.3", 315, 7.7),
        // Second wave offset by 22.5° for density
        ("folder", 22, 8.8),
        ("theatermasks", 67, 9.9),
        ("waveform", 112, 11.0),
        ("person.2", 157, 12.1),
        ("headphones", 202, 13.2),
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header with Gradient
                    ZStack {
                        // Gradient background that fades to clear
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .white, location: 0),
                                    .init(color: .white, location: 0.7),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Distant stars (or clouds in light mode)
                        StarsView(colorScheme: colorScheme)

                        // Content
                        VStack(spacing: 16) {
                            // Search icon with animated glow effect
                            ZStack {
                                // Flying symbols (Time Machine style) - centered on search icon
                                ForEach(Array(flyingSymbols.enumerated()), id: \.offset) { _, item in
                                    FlyingSymbolView(
                                        symbol: item.symbol,
                                        angle: item.angle,
                                        delay: item.delay
                                    )
                                }

                                // Outer expanding rings
                                ForEach(0..<3, id: \.self) { index in
                                    Circle()
                                        .stroke(.white.opacity(ringAnimation ? 0 : 0.3), lineWidth: 2)
                                        .frame(width: 70, height: 70)
                                        .scaleEffect(ringAnimation ? 2.2 : 1)
                                        .animation(
                                            .easeOut(duration: 2.5)
                                            .repeatForever(autoreverses: false)
                                            .delay(Double(index) * 0.8),
                                            value: ringAnimation
                                        )
                                }

                                // Pulsing outer glow
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                .white.opacity(pulseAnimation ? 0.4 : 0.2),
                                                .white.opacity(0)
                                            ],
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: pulseAnimation ? 70 : 55
                                        )
                                    )
                                    .frame(width: 140, height: 140)
                                    .animation(
                                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                                        value: pulseAnimation
                                    )

                                // Inner soft glow
                                Circle()
                                    .fill(.white.opacity(glowAnimation ? 0.35 : 0.25))
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 15)
                                    .animation(
                                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                        value: glowAnimation
                                    )

                                // Solid backdrop circle
                                Circle()
                                    .fill(.white.opacity(0.25))
                                    .frame(width: 70, height: 70)

                                // The icon with subtle scale animation
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .white.opacity(0.8), radius: glowAnimation ? 12 : 6)
                                    .scaleEffect(glowAnimation ? 1.05 : 1.0)
                                    .animation(
                                        .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                        value: glowAnimation
                                    )
                            }
                            .onAppear {
                                glowAnimation = true
                                pulseAnimation = true
                                ringAnimation = true
                            }

                            VStack(spacing: .spacing(.nano)) {
                                Text("Busca")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)

                                Text("Universal")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)
                            }

                            Text("Uma nova forma de encontrar tudo")
                                .font(.subheadline)
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.primary.opacity(0.85)
                                        : Color(red: 0.0, green: 0.3, blue: 0.5)
                                )
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 300)

                    // Features Section
                    VStack(alignment: .leading, spacing: 24) {
                        ItemView(
                            icon: "square.grid.2x2",
                            title: "Tudo Em Um Só Lugar",
                            message: "Encontre vírgulas, músicas, autores, pastas e reações com uma única busca."
                        )

                        ItemView(
                            icon: "text.magnifyingglass",
                            title: "Busca no Conteúdo",
                            message: "Encontre palavras dentro do que é dito nas vírgulas e músicas, com trechos destacados mostrando o contexto."
                        )

                        if UIDevice.isIOS26OrLater {
                            ItemView(
                                icon: "hand.tap",
                                title: "Acesso Facilitado",
                                message: "No \(currentOSName), a busca agora tem um \(searchButtonPlacement)."
                            )
                        } else {
                            ItemView(
                                icon: "checkmark.circle",
                                title: "No Mesmo Lugar de Sempre",
                                message: "A busca continua no topo da tela, no mesmo lugar que você já conhece."
                            )
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center) {
                    dismissButton

                    Spacer()
                        .frame(height: hasHomeIndicator ? 40 : 16)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.systemBackground)
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }

    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                appMemory.hasSeenUniversalSearchWhatsNewScreen(true)
                dismiss()
            } label: {
                Text("Bora buscar!")
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(.blue)
        } else {
            Button {
                appMemory.hasSeenUniversalSearchWhatsNewScreen(true)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Bora buscar!")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .largeRoundedRectangleBorderedProminent(colored: Color(red: 0.2, green: 0.5, blue: 1.0))
        }
    }
}

// MARK: - Subviews

extension IntroducingUniversalSearchView {

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

    struct ItemView: View {

        let icon: String
        let title: String
        let message: String

        private let iconColor = Color(red: 0.2, green: 0.5, blue: 1.0)

        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("As Standalone View") {
    IntroducingUniversalSearchView(appMemory: AppPersistentMemory.shared)
}

#Preview("As Sheet") {
    VStack {
        Text("Stuff")
        Text("Stuff")
        Text("Stuff")
    }
    .sheet(isPresented: .constant(true)) {
        IntroducingUniversalSearchView(appMemory: AppPersistentMemory.shared)
    }
}
