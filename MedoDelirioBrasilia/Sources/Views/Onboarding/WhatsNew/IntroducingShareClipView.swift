//
//  IntroducingShareClipView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 26/07/26.
//

import SwiftUI

struct IntroducingShareClipView: View {

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

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.20, green: 0.10, blue: 0.0),
                Color(red: 0.35, green: 0.16, blue: 0.0),
                Color(red: 0.45, green: 0.22, blue: 0.0)
            ]
        } else {
            return [
                Color(red: 0.95, green: 0.45, blue: 0.05),
                Color(red: 1.00, green: 0.55, blue: 0.15),
                Color(red: 1.00, green: 0.65, blue: 0.25)
            ]
        }
    }

    private let accentOrange = Color.orange

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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

                        VStack(spacing: 16) {
                            ZStack {
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

                                Circle()
                                    .fill(.white.opacity(0.25))
                                    .frame(width: 70, height: 70)

                                Image(systemName: "scissors")
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

                            Text("NOVIDADE DOS EPISÓDIOS")
                                .font(.footnote)
                                .bold()
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.primary.opacity(0.85)
                                        : Color(red: 0.35, green: 0.16, blue: 0.0)
                                )

                            Text("Crie Clipes")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)

                            Text("Transforme qualquer trecho em vídeo")
                                .font(.subheadline)
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.primary.opacity(0.85)
                                        : Color(red: 0.35, green: 0.16, blue: 0.0)
                                )
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 320)
                    .clipped()

                    VStack(alignment: .leading, spacing: 24) {
                        featureItem(
                            icon: "waveform",
                            title: "Escolha o Trecho",
                            message: "Selecione o início e o fim do clipe direto na forma de onda do episódio."
                        )

                        featureItem(
                            icon: "video",
                            title: "Gere um Vídeo",
                            message: "Um vídeo quadrado pronto pra compartilhar, com capa, título e progresso do episódio."
                        )

                        featureItem(
                            icon: "square.and.arrow.up",
                            title: "Compartilhe Onde Quiser",
                            message: "Envie pro Instagram, WhatsApp, ou salve direto na galeria de Fotos."
                        )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    dismissButton

                    Spacer()
                        .frame(height: hasHomeIndicator ? 40 : 16)
                }
                .padding(.top, 10)
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
                appMemory.hasSeenShareClipWhatsNewScreen(true)
                Task { await AnalyticsService().send(originatingScreen: "ShareClipWhatsNew", action: "dismissed") }
                dismiss()
            } label: {
                Text("Vamos lá!")
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(accentOrange)
        } else {
            Button {
                appMemory.hasSeenShareClipWhatsNewScreen(true)
                Task { await AnalyticsService().send(originatingScreen: "ShareClipWhatsNew", action: "dismissed") }
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Vamos lá!")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .largeRoundedRectangleBorderedProminent(colored: accentOrange)
        }
    }

    private func featureItem(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accentOrange)
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

// MARK: - Preview

#Preview("As Standalone View") {
    IntroducingShareClipView(appMemory: AppPersistentMemory.shared)
}

#Preview("As Sheet") {
    VStack {
        Text("Stuff")
        Text("Stuff")
        Text("Stuff")
    }
    .sheet(isPresented: .constant(true)) {
        IntroducingShareClipView(appMemory: AppPersistentMemory.shared)
    }
}
