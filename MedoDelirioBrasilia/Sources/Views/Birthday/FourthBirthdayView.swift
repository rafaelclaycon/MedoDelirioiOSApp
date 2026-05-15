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
    @State private var confettiIsFalling = false
    @State private var presentAlert = false

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
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroHeader

                    VStack(spacing: .spacing(.large)) {
                        Text("Um obrigado gigante do Rafael (criador do app iOS) e dos criadores do podcast.")
                            .font(.body)
                            .bold()
                            .foregroundStyle(.primary)

                        Text("Há 4 anos, no dia 20 de maio de 2022, esse app foi lançado pela primeira vez na App Store. O que começou como uma brincadeira virou algo que centenas de pessoas usam todos os dias para rir, reagir e compartilhar as partes mais marcantes do podcast.\n\nNada disso existiria sem vocês. Obrigado por cada compartilhamento, cada sugestão e cada risada.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let audioURL = Bundle.main.url(forResource: "cristiano-4-anos", withExtension: "mp3") {
                            AudioMessageBubbleView(
                                audioURL: audioURL,
                                senderName: "Cristiano Botafogo",
                                senderImage: Image("cristiano")
                            )
                        }

                        Text("Que tal pingar um capilé pro app?")
                            .font(.body)
                            .foregroundStyle(.secondary)
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

//                        VStack(spacing: .spacing(.small)) {
//                            GlassButton(
//                                symbol: "app.gift",
//                                title: "Ativar Ícone Comemorativo",
//                                color: accentGreen,
//                                fullWidth: true,
//                                action: {
//                                    AppIcon().setAlternateAppIcon(icon: .birthday)
//                                    withAnimation {
//                                        didChangeIcon = true
//                                    }
//                                }
//                            )
//
//                            if didChangeIcon {
//                                Label("Ícone ativado!", systemImage: "checkmark.circle.fill")
//                                    .font(.subheadline)
//                                    .foregroundStyle(.green)
//                                    .transition(.opacity.combined(with: .move(edge: .top)))
//                            }
//                        }

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

            BirthdayConfettiView(isFalling: confettiIsFalling)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea(edges: .top)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onAppear {
            confettiIsFalling = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                confettiIsFalling = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                CloseButton {
                    dismiss()
                }
            }
        }
        .alert(
            "Chave Pix Copiada!",
            isPresented: $presentAlert
        ) {
            Button("OK") { presentAlert.toggle() }
        } message: {
            Text("Cole no app do seu banco para enviar.\n\nObrigado! 💚")
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

    private static func sendAnalytics(for action: String) async {
        await AnalyticsService().send(
            originatingScreen: "FourthBirthdayView",
            action: action
        )
    }
}

// MARK: - Confetti

private struct BirthdayConfettiView: View {

    let isFalling: Bool

    private static let colors: [Color] = [
        .rubyRed,
        .darkerGreen,
        .yellow,
        .blue,
        .pink,
        .orange,
        .purple
    ]

    private let pieces = BirthdayConfettiPiece.all

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    BirthdayConfettiShapeView(kind: piece.shape)
                        .fill(Self.colors[piece.colorIndex % Self.colors.count])
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(isFalling ? piece.finalRotation : piece.initialRotation))
                        .position(
                            x: xPosition(for: piece, in: geometry.size),
                            y: yPosition(for: piece, in: geometry.size)
                        )
                        .animation(
                            .timingCurve(0.16, 0.85, 0.28, 1.0, duration: piece.duration)
                                .delay(piece.delay),
                            value: isFalling
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private func xPosition(for piece: BirthdayConfettiPiece, in size: CGSize) -> CGFloat {
        if isFalling {
            min(max(size.width * piece.xFraction + piece.drift, -30), size.width + 30)
        } else {
            size.width / 2 + piece.initialSpread
        }
    }

    private func yPosition(for piece: BirthdayConfettiPiece, in size: CGSize) -> CGFloat {
        isFalling ? size.height + 80 : -40 - piece.popHeight
    }
}

private struct BirthdayConfettiPiece: Identifiable {

    let id: Int
    let xFraction: CGFloat
    let initialSpread: CGFloat
    let drift: CGFloat
    let popHeight: CGFloat
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let duration: Double
    let initialRotation: Double
    let finalRotation: Double
    let colorIndex: Int
    let shape: BirthdayConfettiShape

    static let all: [BirthdayConfettiPiece] = (0..<90).map { index in
        BirthdayConfettiPiece(
            id: index,
            xFraction: CGFloat(unit(index, salt: 12.9898)),
            initialSpread: CGFloat((unit(index, salt: 78.233) - 0.5) * 90),
            drift: CGFloat((unit(index, salt: 37.719) - 0.5) * 120),
            popHeight: CGFloat(unit(index, salt: 19.19) * 70),
            width: CGFloat(5 + unit(index, salt: 91.7) * 7),
            height: CGFloat(8 + unit(index, salt: 53.37) * 14),
            delay: unit(index, salt: 29.17) * 0.8,
            duration: 2.6 + unit(index, salt: 43.11) * 1.5,
            initialRotation: unit(index, salt: 61.4) * 120,
            finalRotation: 540 + unit(index, salt: 17.31) * 900,
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

// MARK: - Preview

#Preview {
    VStack {
        Text("Background View")
    }
    .sheet(isPresented: .constant(true)) {
        FourthBirthdayView()
    }
}
