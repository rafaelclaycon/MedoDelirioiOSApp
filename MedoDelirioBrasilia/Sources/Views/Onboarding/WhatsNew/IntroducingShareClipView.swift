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
                            TimelineCutHeroView()
                                .frame(height: 60)
                                .padding(.bottom, 8)

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
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 280)
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
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    Text("Pra começar, reproduza um episódio na aba Episódios e toque em Compartilhar Trecho na tela de Reproduzindo Agora.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

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
                Text("Bora cortar!")
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
                    Text("Bora cortar!")
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

// MARK: - Timeline Cut Hero

extension IntroducingShareClipView {

    /// Animates the "cutting a piece out of a timeline" analogy: a segment
    /// grows out from the center of a track, scissors snip each edge, the
    /// segment pulses to mark it as captured, then everything resets.
    ///
    /// Driven by a single sequential `Task` rather than several independent
    /// `.repeatForever` animations — that combination is what made the
    /// previous glow/pulse/ring hero look glitchy, since overlapping
    /// auto-reversing loops drift out of sync with each other over time.
    struct TimelineCutHeroView: View {

        private enum Phase {
            case collapsed, selecting, snipLeft, snipRight, captured
        }

        @State private var phase: Phase = .collapsed

        private let trackWidth: CGFloat = 220
        private let trackHeight: CGFloat = 10
        private let segmentFraction: CGFloat = 0.46

        private var segmentWidth: CGFloat {
            phase == .collapsed ? 0 : trackWidth * segmentFraction
        }

        private var segmentOpacity: Double {
            phase == .collapsed ? 0 : 1
        }

        private var capturedScale: CGFloat {
            phase == .captured ? 1.1 : 1.0
        }

        private var leftSnipScale: CGFloat { phase == .snipLeft ? 1.35 : 1.0 }
        private var leftSnipAngle: Angle { phase == .snipLeft ? .degrees(-16) : .degrees(0) }
        private var rightSnipScale: CGFloat { phase == .snipRight ? 1.35 : 1.0 }
        private var rightSnipAngle: Angle { phase == .snipRight ? .degrees(16) : .degrees(0) }

        var body: some View {
            ZStack {
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: trackWidth, height: trackHeight)

                Capsule()
                    .fill(.white)
                    .frame(width: segmentWidth, height: trackHeight)
                    .opacity(segmentOpacity)
                    .scaleEffect(capturedScale)
                    .shadow(color: .white.opacity(phase == .captured ? 0.7 : 0), radius: 10)

                scissors
                    .scaleEffect(leftSnipScale)
                    .rotationEffect(leftSnipAngle)
                    .opacity(segmentOpacity)
                    .offset(x: -segmentWidth / 2, y: -trackHeight * 1.6)

                scissors
                    .scaleEffect(x: -1, y: 1)
                    .scaleEffect(rightSnipScale)
                    .rotationEffect(rightSnipAngle)
                    .opacity(segmentOpacity)
                    .offset(x: segmentWidth / 2, y: -trackHeight * 1.6)
            }
            .task {
                await runLoop()
            }
        }

        private var scissors: some View {
            Image(systemName: "scissors")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }

        private func runLoop() async {
            while !Task.isCancelled {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { phase = .selecting }
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { phase = .snipLeft }
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }

                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { phase = .snipRight }
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.4)) { phase = .captured }
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }

                withAnimation(.easeIn(duration: 0.35)) { phase = .collapsed }
                try? await Task.sleep(for: .seconds(0.5))
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
