//
//  FourthAnniversaryView.swift
//  MedoDelirioBrasilia
//

import SwiftUI

struct FourthAnniversaryView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var glowAnimation = false
    @State private var pulseAnimation = false
    @State private var ringAnimation = false
    @State private var confettiIsFalling = false
    @State private var presentAlert = false
    @State private var confettiTrigger = 0
    @State private var confettiOriginY: CGFloat = 300

    @State private var mostSharedSound: AnyEquatableMedoContent?
    @State private var playable: PlayableContentState?
    private var contentRepository: ContentRepositoryProtocol
    @State private var viewModel: ContentGridViewModel
    @State private var shareSheetURL: URLWrapper?

    // MARK: - Computed Properties

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
        ("radio", 45, 1.1),
        ("star.fill", 90, 2.2),
        ("heart.fill", 135, 3.3),
        ("party.popper", 180, 4.4),
        ("gift", 225, 5.5),
        ("radio", 270, 6.6),
        ("star.fill", 315, 7.7),
        ("heart.fill", 22, 8.8),
        ("party.popper", 67, 9.9),
        ("gift", 112, 11.0),
        ("quote.bubble.fill", 157, 12.1),
        ("star.fill", 202, 13.2),
    ]

    private let accentGreen: Color = .darkerGreen

    init() {

        self.contentRepository = ContentRepository(database: LocalDatabase.shared)
        self.viewModel = ContentGridViewModel(
            contentRepository: contentRepository,
            userFolderRepository: UserFolderRepository(database: LocalDatabase.shared),
            contentFileManager: ContentFileManager(),
            screen: .mainContentView,
            menuOptions: [.sharingOptions(), .organizingOptions(), .detailsOptions()],
            currentListMode: .constant(.regular),
            toast: .constant(nil),
            floatingOptions: .constant(nil),
            analyticsService: AnalyticsService()
        )
    }

    // MARK: - View Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        confettiTrigger += 1
                        Task {
                            await Self.sendAnalytics(for: "didTapShootConfettiAgain")
                        }
                    } label: {
                        Label("Lançar de novo", systemImage: "party.popper")
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.frame(in: .global).minY
                    } action: { minY in
                        confettiOriginY = minY - 48
                    }

                    VStack(spacing: .spacing(.large)) {
                        Text("Em 20 de maio de 2022 o app Medo e Delírio era lançado pela primeira vez para iPhone. O que começou como uma brincadeira virou algo que centenas de pessoas usam todos os dias para rir, reagir e compartilhar as partes mais marcantes do podcast.\n\nNesses anos tivemos...")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        StatView(
                            title: "29.749",
                            subtitle: "usuários únicos"
                        )

                        StatView(
                            title: "720.763",
                            subtitle: "compartilhamentos de vírgulas e músicas"
                        )

                        StatView(
                            title: "4.080",
                            subtitle: "usuários mensais (média dos últimos 3 meses)"
                        )

                        if let mostSharedSound {
                            VStack(spacing: .spacing(.xSmall)) {
                                PlayableContentView(
                                    content: mostSharedSound,
                                    showNewTag: false,
                                    favorites: Set<String>(),
                                    highlighted: Set<String>(),
                                    nowPlaying: viewModel.nowPlayingKeeper,
                                    selectedItems: Set<String>(),
                                    currentContentListMode: .constant(.regular)
                                )
                                .contentShape(
                                    .contextMenuPreview,
                                    RoundedRectangle(cornerRadius: .spacing(.large), style: .continuous)
                                )
                                .onTapGesture {
                                    viewModel.onContentSelected(mostSharedSound, loadedContent: [mostSharedSound])
                                }
                                .contextMenu {
                                    contextMenuOptionsView(
                                        content: mostSharedSound,
                                        menuOptions: [.sharingOptions()],
                                        favorites: viewModel.favoritesKeeper,
                                        loadedContent: [mostSharedSound]
                                    )
                                }
                                .frame(width: 180)

                                Text("vírgula mais compartilhada")
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Text("Nada disso existiria sem vocês. Esse app é desenvolvido de forma independente, por amor ao podcast.\n\n**Obrigado por cada compartilhamento, cada sugestão e cada risada.**\n\nUma mensagem especial do Cristiano para vocês:")

                        if let audioURL = Bundle.main.url(forResource: "cristiano-4-anos", withExtension: "mp3") {
                            AudioMessageBubbleView(
                                audioURL: audioURL,
                                senderName: "Cristiano Botafogo",
                                senderImage: Image("cristiano")
                            )
                        }

                        Text("Que tal pingar um capilé pro app?")
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)

                        GlassButton(
                            symbol: "arrow.trianglehead.2.counterclockwise",
                            title: "Apoio recorrente",
                            color: .rubyRed,
                            fullWidth: true,
                            action: {
                                OpenUtility.open(link: "https://apoia.se/app-medo-delirio-ios")
                                Task {
                                    await Self.sendAnalytics(for: "didTapApoiase")
                                }
                            }
                        )

                        GlassButton(
                            symbol: "document.on.document",
                            title: "Apoio pontual",
                            color: .blue,
                            fullWidth: true,
                            action: {
                                UIPasteboard.general.string = HelpTheAppView.pixKey
                                presentAlert = true
                                Task {
                                    await Self.sendAnalytics(for: "didTapPix")
                                }
                            }
                        )

                        HStack {
                            Spacer()

                            Text("Pelos próximos 4! 🥂")
                                .font(.title3)
                                .bold()
                                .multilineTextAlignment(.center)

                            Spacer()
                        }
                        .padding(.vertical, .spacing(.xLarge))
                    }
                    .padding(.top, .spacing(.large))
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear {
            confettiIsFalling = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                confettiIsFalling = true
            }
            loadMostSharedSound()
        }
        .overlay {
            BirthdayConfettiView(isFalling: confettiIsFalling, originY: confettiOriginY, trigger: confettiTrigger)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .alert(
            "Chave Pix Copiada!",
            isPresented: $presentAlert
        ) {
            Button("OK") { presentAlert.toggle() }
        } message: {
            Text("Cole no app do seu banco para enviar.\n\nObrigado! 💚")
        }
        .playableContentUI(
            state: viewModel.playable,
            toast: .constant(nil)
        )
        .sheet(item: $shareSheetURL) { wrapper in
            ActivityView(activityItems: [wrapper.url])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Most Shared Enablers

    @MainActor @ViewBuilder
    private func contextMenuOptionsView(
        content: AnyEquatableMedoContent,
        menuOptions: [ContextMenuSection],
        favorites: Set<String>,
        loadedContent: [AnyEquatableMedoContent]
    ) -> some View {
        ForEach(menuOptions, id: \.title) { section in
            Section {
                ForEach(section.options(content)) { option in
                    if option.appliesTo.contains(content.type) {
                        optionRow(
                            option: option,
                            isFavorite: favorites.contains(content.id),
                            content: content,
                            loadedContent: loadedContent
                        )
                    }
                }
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func optionRow(
        option: ContextMenuOption,
        isFavorite: Bool,
        content: AnyEquatableMedoContent,
        loadedContent: [AnyEquatableMedoContent]
    ) -> some View {
        let optionTitle = option.title(isFavorite)

        Button {
            guard optionTitle != Shared.shareSoundButtonText else {
                do {
                    let url = try content.fileURL()
                    print(url.absoluteString)
                    shareSheetURL = URLWrapper(url: url)
                } catch {
                    debugPrint("Erro ao tentar obter URL para o som mais compartilhado")
                }
                return
            }

            option.action(
                viewModel,
                ContextMenuPassthroughData(
                    selectedContent: content,
                    loadedContent: loadedContent,
                    isFavoritesOnlyView: false
                )
            )
        } label: {
            Label(optionTitle, systemImage: option.symbol(isFavorite))
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

    // MARK: - Helper Functions

    private func loadMostSharedSound() {
        if playable == nil {
            playable = PlayableContentState(
                contentRepository: contentRepository,
                contentFileManager: ContentFileManager(),
                analyticsService: AnalyticsService(),
                screen: .anniversaryView,
                toast: .constant(nil)
            )
        }

        do {
            let sound = try contentRepository.content(withIds: ["87EFA0B2-CC38-4B9F-B441-A832300CD483"]).first
            self.mostSharedSound = sound
        } catch {
            debugPrint("Problema carregando som mais popular: \(error.localizedDescription)")
            Task {
                await Self.sendAnalytics(for: "issueLoadingMostSharedSound")
            }
        }
    }

    private static func sendAnalytics(for action: String) async {
        await AnalyticsService().send(
            originatingScreen: "FourthBirthdayView",
            action: action
        )
    }
}

// MARK: - Subviews

extension FourthAnniversaryView {

    struct StatView: View {

        let title: String
        let subtitle: String

        var body: some View {
            VStack(spacing: .spacing(.nano)) {
                Text(title)
                    .font(.largeTitle)
                    .bold()

                Text(subtitle)
            }
            .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Confetti

private struct BirthdayConfettiView: View {

    let isFalling: Bool
    /// Y coordinate where the cannon fires from. Defaults to bottom of the 300pt header.
    var originY: CGFloat = 300
    var trigger: Int = 0

    @State private var startDate: Date = .distantFuture

    private static let colors: [Color] = [
        .rubyRed, .darkerGreen, .yellow, .blue, .pink, .orange, .purple
    ]

    private let pieces = BirthdayConfettiPiece.all

    /// Pixels per second² — tune to taste. Higher = pieces fall back faster.
    private let gravity: CGFloat = 700

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let elapsed = max(0, context.date.timeIntervalSince(startDate))

                ZStack {
                    ForEach(pieces) { piece in
                        let visible = elapsed >= piece.delay
                        let t: CGFloat = CGFloat(max(0, elapsed - piece.delay))

                        let x: CGFloat = geometry.size.width / 2 + piece.velocityX * t

                        let gravityTerm: CGFloat = 0.5 * gravity * t * t
                        let y: CGFloat = originY + piece.velocityY * t + gravityTerm

                        let rotation: Double = piece.initialRotation + Double(t) * piece.rotationSpeed

                        BirthdayConfettiShapeView(kind: piece.shape)
                            .fill(Self.colors[piece.colorIndex % Self.colors.count])
                            .frame(width: piece.width, height: piece.height)
                            .rotationEffect(.degrees(rotation))
                            .position(x: x, y: y)
                            .opacity(visible ? 1 : 0)
                    }
                }
            }
        }
        .onAppear {
            if isFalling { startDate = Date() }
        }
        .onChange(of: isFalling) { _, newValue in
            startDate = newValue ? Date() : .distantFuture
        }
        .onChange(of: trigger) { _, _ in
            // Re-fire whenever the trigger changes (only if we're "armed")
            if isFalling {
                startDate = Date()
            }
        }
    }
}

private struct BirthdayConfettiPiece: Identifiable {

    let id: Int
    let velocityX: CGFloat        // horizontal speed (pts/s)
    let velocityY: CGFloat        // vertical speed (pts/s) — negative = upward
    let rotationSpeed: Double     // degrees per second
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let initialRotation: Double
    let colorIndex: Int
    let shape: BirthdayConfettiShape

    static let all: [BirthdayConfettiPiece] = (0..<90).map { index in
        // Fan-shaped launch angle: from -135° to -45°
        // (i.e. up-left through straight-up to up-right).
        // In screen coordinates, "up" is negative Y, so sin(angle) is negative.
        let angleProgress = unit(index, salt: 12.9898)             // 0...1
        let angle = -.pi * (0.25 + angleProgress * 0.5)            // -π/4 ... -3π/4

        // Initial speed varies a bit so pieces don't all reach the same height.
        let speed = 550 + unit(index, salt: 78.233) * 450          // 550...1000 pts/s

        return BirthdayConfettiPiece(
            id: index,
            velocityX: CGFloat(cos(angle) * speed),
            velocityY: CGFloat(sin(angle) * speed),                // negative = up
            rotationSpeed: 180 + unit(index, salt: 19.19) * 540,   // 180...720 deg/s
            width: CGFloat(5 + unit(index, salt: 91.7) * 7),
            height: CGFloat(8 + unit(index, salt: 53.37) * 14),
            delay: unit(index, salt: 29.17) * 0.35,                // small stagger
            initialRotation: unit(index, salt: 61.4) * 360,
            colorIndex: index,
            shape: BirthdayConfettiShape(rawValue: index % BirthdayConfettiShape.allCases.count) ?? .rectangle
        )
    }

    private static func unit(_ index: Int, salt: Double) -> Double {
        let value = sin((Double(index) + 1) * salt) * 43_758.5453
        return value - floor(value)
    }
}

private enum BirthdayConfettiShape: Int, CaseIterable {
    case rectangle
    case capsule
    case circle
}

private struct BirthdayConfettiShapeView: Shape {

    let kind: BirthdayConfettiShape

    func path(in rect: CGRect) -> Path {
        switch kind {
        case .rectangle:
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .path(in: rect)
        case .capsule:
            Capsule()
                .path(in: rect)
        case .circle:
            Circle()
                .path(in: rect)
        }
    }
}

struct URLWrapper: Identifiable {

    let url: URL

    var id: String {
        url.absoluteString
    }
}

struct ActivityView: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    VStack {
        Text("Background View")
    }
    .sheet(isPresented: .constant(true)) {
        FourthAnniversaryView()
    }
}
