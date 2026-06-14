//
//  OnboardingView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 18/08/22.
//

import SwiftUI

// MARK: - Disabled Feature: Content Download Choice
// The following enum and views (AskDoFirstContentUpdateView, OptionBox) are preserved
// for a future feature that lets users choose when to download content on first launch.

enum ContentDownloadChoice {
    case downloadLater
    case downloadAllNow
}

enum OnboardingStep: Hashable {
    case explicitContent
    case notifications
    case episodeNotifications
}

struct OnboardingView: View {

    // NOTE: Content Download Choice feature is disabled for now.
    // The selectionAction and AskDoFirstContentUpdateView are preserved for future use.
    // var selectionAction: ((ContentDownloadChoice) -> Void)? = nil

    @State private var path = NavigationPath()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView {
                path.append(OnboardingStep.explicitContent)
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .explicitContent:
                    AskShowExplicitContentView(
                        showAction: {
                            UserSettings().setShowExplicitContent(to: true)
                        },
                        advanceAction: {
                            path.append(OnboardingStep.notifications)
                        }
                    )

                case .notifications:
                    AskAllowNotificationsView(
                        allowAction: {
                            Task {
                                await NotificationAide.registerForRemoteNotifications()
                                AppPersistentMemory.shared.hasShownNotificationsOnboarding(true)
                                path.append(OnboardingStep.episodeNotifications)
                            }
                        },
                        dontAllowAction: {
                            AppPersistentMemory.shared.hasShownNotificationsOnboarding(true)
                            dismiss()
                        }
                    )

                case .episodeNotifications:
                    AskEpisodeNotificationsView(
                        optInAction: {
                            Task {
                                let result = await EpisodeNotificationSubscriber.subscribe()
                                if case .success = result {
                                    await AnalyticsService().send(originatingScreen: "Onboarding", action: "episode_notifications_opted_in")
                                }
                                dismiss()
                            }
                        },
                        skipAction: {
                            Task { await AnalyticsService().send(originatingScreen: "Onboarding", action: "episode_notifications_skipped") }
                            dismiss()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Subviews

extension OnboardingView {

    struct WelcomeView: View {

        let advanceAction: () -> Void

        @Environment(\.colorScheme) private var colorScheme

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

        private let accentGreen = Color(red: 0.0, green: 0.64, blue: 0.02)

        private let flyingSymbols: [(symbol: String, angle: Double, delay: Double)] = [
            ("speaker.wave.2", 0, 0.0),
            ("waveform", 45, 1.1),
            ("music.note", 90, 2.2),
            ("face.smiling", 135, 3.3),
            ("theatermasks", 180, 4.4),
            ("quote.bubble", 225, 5.5),
            ("speaker.wave.2", 270, 6.6),
            ("waveform", 315, 7.7),
            ("music.note", 22, 8.8),
            ("theatermasks", 67, 9.9),
            ("quote.bubble", 112, 11.0),
            ("face.smiling", 157, 12.1),
            ("waveform", 202, 13.2),
        ]

        var body: some View {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero Header
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

                                    // Layer several sine waves at irrational ratios for organic, non-repeating motion
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

                            Text("Eu não tô doido, não!")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 300)

                    // Selling Points
                    VStack(alignment: .leading, spacing: 24) {
                        featureItem(
                            icon: "quote.bubble",
                            title: "Sons e Músicas",
                            message: "Centenas de vírgulas e músicas do podcast para ouvir e compartilhar com seus amigos."
                        )

                        featureItem(
                            icon: "theatermasks",
                            title: "Reações",
                            message: "Encontre a resposta perfeita para o grupo com sons organizados por emoção, personagem e momento."
                        )

                        featureItem(
                            icon: "radio",
                            title: "Episódios no App",
                            message: "Ouça todos os episódios direto no app, com marcadores e favoritos."
                        )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    GlassButton(
                        title: "BORA!",
                        color: .darkerGreen,
                        fullWidth: true,
                        action: advanceAction
                    )

                    Spacer()
                        .frame(height: hasHomeIndicator ? 40 : 16)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color.systemBackground)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }

        private func featureItem(icon: String, title: String, message: String) -> some View {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .imageScale(.large)
                    .foregroundStyle(accentGreen)
                    .frame(width: 40, height: 40)
                    .background(accentGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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

    struct AskAllowNotificationsView: View {

        let allowAction: () -> Void
        let dontAllowAction: () -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .center) {
                    NotificationsSymbol()

                    Text("Saiba das Novidades Assim que Elas Chegam")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical)

                    Text("Receba notificações sobre os últimos sons, tendências e novos recursos.\n\nA frequência das notificações será baixa, no máximo 2 por semana.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 18) {
                    GlassButton(
                        title: "Permitir notificações",
                        color: .green,
                        fullWidth: true,
                        action: allowAction
                    )

                    GlassButton(
                        title: "Ah é, é? F***-se",
                        color: .clear,
                        fullWidth: true,
                        action: dontAllowAction
                    )

                    Text("Você pode ativar as notificações mais tarde nas Configurações do app.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.systemBackground)
            }
        }
    }

    struct AskShowExplicitContentView: View {

        let showAction: () -> Void
        let advanceAction: () -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .center, spacing: 40) {
                    Image(systemName: "mouth.fill")
                       .resizable()
                       .scaledToFit()
                       .frame(width: 100)
                       .foregroundStyle(Color.red)
                       .overlay(alignment: .bottomLeading) {
                           HStack {
                               Image(systemName: "exclamationmark.bubble.fill")
                                   .font(.system(size: 50))
                                   .scaleEffect(x: -1, y: 1)
                                   .foregroundStyle(Color.blue)
                                   .offset(x: -60, y: -40)

                               Image(systemName: "asterisk")
                                   .font(.system(size: 40))
                                   .foregroundStyle(Color.orange)
                                   .offset(x: 26, y: 30)
                           }
                           .overlay {
                               HStack {
                                   Text("🦎")
                                       .font(.system(size: 50))
                                       .foregroundStyle(Color.orange)
                                       .offset(x: -55, y: 50)
                                   Text("🐍")
                                       .font(.system(size: 50))
                                       .scaleEffect(x: -1, y: 1)
                                       .foregroundStyle(Color.blue)
                                       .offset(x: 45, y: -40)
                               }
                           }
                       }
                       .padding([.top, .bottom], 40)

                    Text(verbatim: "Po**a,  c*r*lho")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    Text("Muitos sons contém palavrões e você pode optar por vê-los ou não.")
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 18) {
                    GlassButton(
                        title: "Exibir Conteúdo Sensível",
                        color: .green,
                        fullWidth: true,
                        action: {
                            showAction()
                            advanceAction()
                        }
                    )

                    GlassButton(
                        title: "Não Exibir Conteúdo Sensível",
                        color: .clear,
                        fullWidth: true,
                        action: advanceAction
                    )

                    Text("Você pode mudar isso mais tarde nas Configurações do app.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.systemBackground)
            }
        }
    }

    struct AskEpisodeNotificationsView: View {

        let optInAction: () -> Void
        let skipAction: () -> Void

        var body: some View {
            ScrollView {
                VStack(alignment: .center) {
                    Spacer()
                        .frame(height: 50)

                    Image(systemName: "headphones")
                        .font(.system(size: 74))
                        .foregroundStyle(Color.accentColor)
                        .padding(.bottom, 10)

                    Text("Nunca Perca um Episódio")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical)

                    Text("Receba uma notificação sempre que um novo episódio do podcast estiver disponível.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: 18) {
                    GlassButton(
                        title: "Quero Receber",
                        color: .green,
                        fullWidth: true,
                        action: optInAction
                    )

                    GlassButton(
                        title: "Agora não",
                        color: .clear,
                        fullWidth: true,
                        action: skipAction
                    )

                    Text("Você pode mudar isso mais tarde nas Configurações do app.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.systemBackground)
            }
        }
    }

    struct AskDoFirstContentUpdateView: View {

        let selectionAction: (ContentDownloadChoice) -> Void

        @State private var selectedOption: ContentDownloadChoice? = nil

        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            ScrollView {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 74))
                        .foregroundColor(.orange)

                    Text("Tem Conteúdos Novos Te Esperando")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, .spacing(.large))
                        .padding(.vertical)

                    Text("Novos sons e músicas são baixados sempre que você estiver online. Como deseja prosseguir?")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, .spacing(.large))

                    VStack(spacing: .spacing(.medium)) {
                        OptionBox(
                            icon: "clock.arrow.circlepath",
                            title: "Baixar Depois",
                            description: "Os sons serão baixados conforme você for usando o app. Mais rápido para começar.",
                            isSelected: selectedOption == .downloadLater
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOption = .downloadLater
                            }
                        }

                        OptionBox(
                            icon: "arrow.down.circle.fill",
                            title: "Baixar Tudo Agora",
                            description: "Baixa todos os sons de uma vez. Aproximadamente 3 minutos e 20 MB.",
                            isSelected: selectedOption == .downloadAllNow
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedOption = .downloadAllNow
                            }
                        }
                    }
                    .padding(.horizontal, .spacing(.medium))
                    .padding(.top, .spacing(.medium))
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    Button {
                        if let selectedOption {
                            selectionAction(selectedOption)
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Continuar")
                                .bold()
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .largeRoundedRectangleBorderedProminent(colored: .accentColor)
                    .disabled(selectedOption == nil)
                    .opacity(selectedOption == nil ? 0.5 : 1.0)

                    if UIDevice.deviceType != .iPhone {
                        Text("Caso a tela não feche automaticamente, toque fora dela (na área apagada).")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .font(.callout)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, .spacing(.small))
                .background(Color.systemBackground)
            }
            .sensoryFeedback(.selection, trigger: selectedOption)
        }
    }

    // MARK: - OptionBox Component

    struct OptionBox: View {

        let icon: String
        let title: String
        let description: String
        let isSelected: Bool

        @Environment(\.colorScheme) private var colorScheme

        private var backgroundColor: Color {
            if isSelected {
                return colorScheme == .dark
                    ? Color.accentColor.opacity(0.2)
                    : Color.accentColor.opacity(0.1)
            } else {
                return colorScheme == .dark
                    ? Color.gray.opacity(0.15)
                    : Color.gray.opacity(0.08)
            }
        }

        private var borderColor: Color {
            isSelected ? Color.accentColor : Color.gray.opacity(0.3)
        }

        private var borderWidth: CGFloat {
            isSelected ? 2.5 : 1.0
        }

        var body: some View {
            HStack(alignment: .center, spacing: .spacing(.medium)) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.spacing(.medium))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Previews

#Preview("Full Onboarding") {
    struct SheetHost: View {
        @State private var isPresented = true

        var body: some View {
            Color.clear
                .sheet(isPresented: $isPresented) {
                    OnboardingView()
                }
        }
    }

    return SheetHost()
}

#Preview("Welcome") {
    OnboardingView.WelcomeView(advanceAction: {})
}

#Preview("Explicit Content") {
    OnboardingView.AskShowExplicitContentView(
        showAction: {},
        advanceAction: {}
    )
}

#Preview("Notifications") {
    OnboardingView.AskAllowNotificationsView(
        allowAction: {},
        dontAllowAction: {}
    )
}

#Preview("Episode Notifications") {
    OnboardingView.AskEpisodeNotificationsView(
        optInAction: {},
        skipAction: {}
    )
}

#Preview("First Update - Disabled") {
    NavigationStack {
        OnboardingView.AskDoFirstContentUpdateView(
            selectionAction: { choice in
                print("Selected: \(choice)")
            }
        )
    }
}

#Preview("Option Box - Not Selected") {
    OnboardingView.OptionBox(
        icon: "clock.arrow.circlepath",
        title: "Baixar Depois",
        description: "Os sons serão baixados conforme você for usando o app.",
        isSelected: false
    )
    .padding()
}

#Preview("Option Box - Selected") {
    OnboardingView.OptionBox(
        icon: "arrow.down.circle.fill",
        title: "Baixar Tudo Agora",
        description: "Baixa todos os sons de uma vez. Aproximadamente 3 minutos e 20 MB.",
        isSelected: true
    )
    .padding()
}
