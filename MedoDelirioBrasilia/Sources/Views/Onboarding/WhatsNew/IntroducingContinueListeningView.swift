//
//  IntroducingContinueListeningView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/10/26.
//

import SwiftUI

/// What's New for 13.4: Handoff of the playing episode, the Mac app, and iCloud sync of
/// episode state. Only shown to people who listen to episodes (see `MainView`).
struct IntroducingContinueListeningView: View {

    let appMemory: AppPersistentMemoryProtocol

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.02, green: 0.10, blue: 0.22),
                Color(red: 0.04, green: 0.16, blue: 0.34),
                Color(red: 0.06, green: 0.22, blue: 0.44)
            ]
        } else {
            return [
                Color(red: 0.05, green: 0.40, blue: 0.85),
                Color(red: 0.15, green: 0.52, blue: 0.95),
                Color(red: 0.30, green: 0.64, blue: 1.00)
            ]
        }
    }

    private let accentBlue = Color.blue

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
                            DevicesHeroView()
                                .frame(height: 60)
                                .padding(.bottom, 8)

                            Text("NOVIDADE DOS EPISÓDIOS")
                                .font(.footnote)
                                .bold()
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.primary.opacity(0.85)
                                        : Color(red: 0.02, green: 0.15, blue: 0.35)
                                )

                            Text("Ouça em Um,\nContinue no Outro")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 300)
                    .clipped()

                    VStack(alignment: .leading, spacing: 24) {
                        featureItem(
                            icon: "dock.rectangle",
                            title: "Continue em Outro Aparelho",
                            message: "Com o app aberto no iPhone, o episódio que está tocando aparece no Dock do iPad ou do Mac. Um toque e ele continua de onde parou, e o iPhone pausa sozinho."
                        )

                        featureItem(
                            icon: "macbook",
                            title: "Tem App pro Mac",
                            message: "O Medo e Delírio roda em qualquer Mac com chip da Apple. Procure na Mac App Store, na aba de apps para iPhone e iPad."
                        )

                        featureItem(
                            icon: "checkmark.icloud",
                            title: "Tudo Sincronizado",
                            message: "Onde você parou, os episódios finalizados e os favoritos ficam iguais em todos os seus aparelhos, pelo iCloud."
                        )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    Text("Os aparelhos precisam usar a mesma Conta Apple. Dá pra desligar a sincronização em Configurações › Episódios.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    dismissButton

                    Spacer()
                        .frame(height: 16)
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
        Button {
            appMemory.hasSeenContinueListeningWhatsNewScreen(true)
            Task { await AnalyticsService().send(originatingScreen: "ContinueListeningWhatsNew", action: "dismissed") }
            dismiss()
        } label: {
            Text("Entendi")
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(accentBlue)
    }

    private func featureItem(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accentBlue)
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

// MARK: - Devices Hero

extension IntroducingContinueListeningView {

    /// iPhone, iPad and Mac in a row, with the episode "passing" from one to the next:
    /// the device that has it lights up and lifts, the others dim.
    ///
    /// One sequential `Task`, like `TimelineCutHeroView`, rather than overlapping
    /// `.repeatForever` animations that drift out of sync. Holds still when Reduce
    /// Motion is on.
    struct DevicesHeroView: View {

        private static let devices = ["iphone", "ipad.landscape", "macbook"]

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var activeIndex = 0

        var body: some View {
            HStack(alignment: .bottom, spacing: 28) {
                ForEach(Self.devices, id: \.self) { symbol in
                    let isActive = reduceMotion || symbol == Self.devices[activeIndex]
                    Image(systemName: symbol)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .opacity(isActive ? 1 : 0.4)
                        .scaleEffect(isActive && !reduceMotion ? 1.15 : 1)
                        .offset(y: isActive && !reduceMotion ? -6 : 0)
                        .shadow(color: .white.opacity(isActive && !reduceMotion ? 0.6 : 0), radius: 10)
                }
            }
            .accessibilityHidden(true)
            .task(id: reduceMotion) {
                guard !reduceMotion else { return }
                await runLoop()
            }
        }

        private func runLoop() async {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    activeIndex = (activeIndex + 1) % Self.devices.count
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("As Standalone View") {
    IntroducingContinueListeningView(appMemory: AppPersistentMemory.shared)
}

#Preview("As Sheet") {
    VStack {
        Text("Stuff")
        Text("Stuff")
        Text("Stuff")
    }
    .sheet(isPresented: .constant(true)) {
        IntroducingContinueListeningView(appMemory: AppPersistentMemory.shared)
    }
}
