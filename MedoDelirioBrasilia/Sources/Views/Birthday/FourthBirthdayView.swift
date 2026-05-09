//
//  FourthBirthdayView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

struct FourthBirthdayView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var glowAnimation = false
    @State private var pulseAnimation = false
    @State private var ringAnimation = false
    @State private var didChangeIcon = false

    private var hasHomeIndicator: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return false
        }
        return window.safeAreaInsets.bottom > 0
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.0, green: 0.10, blue: 0.02),
                Color(red: 0.0, green: 0.18, blue: 0.04),
                Color(red: 0.05, green: 0.28, blue: 0.08)
            ]
        } else {
            return [
                Color(red: 0.0, green: 0.52, blue: 0.02),
                Color(red: 0.15, green: 0.65, blue: 0.15),
                Color(red: 0.35, green: 0.78, blue: 0.30)
            ]
        }
    }

    private let flyingSymbols: [(symbol: String, angle: Double, delay: Double)] = [
        ("gift", 0, 0.0),
        ("sparkles", 45, 1.1),
        ("star.fill", 90, 2.2),
        ("heart.fill", 135, 3.3),
        ("party.popper", 180, 4.4),
        ("gift", 225, 5.5),
        ("sparkles", 270, 6.6),
        ("star.fill", 315, 7.7),
        ("heart.fill", 22, 8.8),
        ("party.popper", 67, 9.9),
        ("gift", 112, 11.0),
        ("sparkles", 157, 12.1),
        ("star.fill", 202, 13.2),
    ]

    private let accentGreen: Color = .darkerGreen

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader

                VStack(alignment: .leading, spacing: .spacing(.large)) {
                    Text("Um obrigado gigante do Rafael (criador do app iOS) e dos criadores do podcast.")
                        .font(.body)
                        .bold()
                        .foregroundStyle(.primary)

                    Text("Há 4 anos, no dia 20 de maio de 2022, esse app foi lançado pela primeira vez na App Store. O que começou como uma brincadeira virou algo que centenas de pessoas usam todos os dias para rir, reagir e compartilhar as partes mais marcantes do podcast.\n\nNada disso existiria sem vocês. Obrigado por cada compartilhamento, cada sugestão e cada risada. Que venham muitos mais anos juntos!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let audioURL = Bundle.main.url(forResource: "cristiano-4-anos", withExtension: "mp3") {
                        AudioMessageBubbleView(
                            audioURL: audioURL,
                            senderName: "Cristiano"
                        )
                    }

                    Text("Quer apoiar o app?")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    GlassButton(
                        symbol: "app.gift",
                        title: "Apoio recorrente",
                        color: accentGreen,
                        fullWidth: true,
                        action: {
                            AppIcon().setAlternateAppIcon(icon: .birthday)
                            withAnimation {
                                didChangeIcon = true
                            }
                        }
                    )

                    GlassButton(
                        symbol: "app.gift",
                        title: "Apoio recorrente",
                        color: accentGreen,
                        fullWidth: true,
                        action: {
                            AppIcon().setAlternateAppIcon(icon: .birthday)
                            withAnimation {
                                didChangeIcon = true
                            }
                        }
                    )

                    VStack(spacing: .spacing(.small)) {
                        GlassButton(
                            symbol: "app.gift",
                            title: "Ativar Ícone Comemorativo",
                            color: accentGreen,
                            fullWidth: true,
                            action: {
                                AppIcon().setAlternateAppIcon(icon: .birthday)
                                withAnimation {
                                    didChangeIcon = true
                                }
                            }
                        )

                        if didChangeIcon {
                            Label("Ícone ativado!", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.top, .spacing(.large))
                .padding(.horizontal, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CloseButton {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
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

            IntroducingUniversalSearchView.StarsView(colorScheme: colorScheme)

            VStack(spacing: 16) {
                ZStack {
                    ForEach(Array(flyingSymbols.enumerated()), id: \.offset) { _, item in
                        IntroducingUniversalSearchView.FlyingSymbolView(
                            symbol: item.symbol,
                            angle: item.angle,
                            delay: item.delay
                        )
                    }

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

                    Circle()
                        .fill(.white.opacity(glowAnimation ? 0.35 : 0.25))
                        .frame(width: 80, height: 80)
                        .blur(radius: 15)
                        .animation(
                            .easeInOut(duration: 2).repeatForever(autoreverses: true),
                            value: glowAnimation
                        )

                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let a = sin(t * 1.7) * 0.04
                        let b = sin(t * 2.3) * 0.03
                        let c = sin(t * 0.9) * 0.02
                        let pulse = max(0, a + b + c)
                        let scale = 1.0 + pulse
                        let glowRadius = 8.0 + pulse * 40.0

                        Image("marketing-icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .white.opacity(0.6 + pulse * 4.0), radius: glowRadius)
                            .scaleEffect(scale)
                    }
                }
                .onAppear {
                    glowAnimation = true
                    pulseAnimation = true
                    ringAnimation = true
                }

                Text("4 Anos do App iOS!")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)
            }
            .padding(.vertical, 40)
        }
        .frame(height: 300)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Background View")
    }
    .sheet(isPresented: .constant(true)) {
        FourthBirthdayView()
    }
}
