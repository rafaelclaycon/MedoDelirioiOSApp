//
//  IntroducingElectionLiveView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/09/26.
//

import AudioToolbox
import SwiftUI

/// Announces the election Live Activity before election day: the banner that starts it
/// only shows up once the server switches it on, so this screen tells people when to
/// come back. Not shown after the 2nd round (see `lastDayToShow`).
struct IntroducingElectionLiveView: View {

    let appMemory: AppPersistentMemoryProtocol

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    /// End of the 2nd round, Brasília time. After that the screen would announce the past.
    static let lastDayToShow: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 26)) ?? .distantPast
    }()

    /// Same greens as the Live Activity.
    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.02, green: 0.14, blue: 0.08),
                Color(red: 0.03, green: 0.20, blue: 0.11),
                Color(red: 0.06, green: 0.29, blue: 0.16)
            ]
        } else {
            return [
                Color(red: 0.03, green: 0.20, blue: 0.11),
                Color(red: 0.06, green: 0.29, blue: 0.16),
                Color(red: 0.10, green: 0.42, blue: 0.23)
            ]
        }
    }

    private let accentGreen = Color.green

    @State private var confirmations = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        ZStack {
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            KeypadPatternView()
                        }
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
                            ClashHeroView()
                                .frame(height: 112)
                                .padding(.bottom, 4)

                            Text("NOVIDADE PRAS ELEIÇÕES")
                                .font(.footnote)
                                .bold()
                                .foregroundStyle(Color.white.opacity(0.85))

                            Text("Apuração ao Vivo")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)
                        }
                        .padding(.vertical, 40)
                    }
                    .frame(height: 320)
                    .clipped()

                    VStack(alignment: .leading, spacing: 24) {
                        featureItem(
                            icon: "lock.iphone",
                            title: "Na Tela Bloqueada",
                            message: "Os dois mais votados para Presidente e quanto já foi totalizado, atualizando sozinho, sem abrir o app."
                        )

                        featureItem(
                            icon: "checkmark.seal",
                            title: "Dados Oficiais do TSE",
                            message: "Os números vêm direto da divulgação oficial do Tribunal Superior Eleitoral."
                        )

                        // The 1st round (October 4) is over: anyone seeing this now, like
                        // someone who just installed the app, needs the 2nd round's date.
                        featureItem(
                            icon: "calendar",
                            title: "2º Turno: 25 de Outubro, às 17h",
                            message: "Lula e Flávio Bolsonaro. Um banner aparece no topo das Vírgulas quando a apuração começar, no horário de Brasília."
                        )
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .center, spacing: .spacing(.medium)) {
                    Text("As Atividades ao Vivo precisam estar ativadas nos Ajustes do iPhone.")
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

    /// The ballot machine's CONFIRMA key, braille and all.
    private var dismissButton: some View {
        Button {
            confirmations += 1
            ConfirmaKey.playSound()
            close()
        } label: {
            ConfirmaKeyLabel()
        }
        .buttonStyle(ConfirmaKeyStyle())
        .sensoryFeedback(.impact(weight: .heavy), trigger: confirmations)
        .accessibilityLabel("Confirma")
        .accessibilityHint("Fecha as novidades")
    }

    private func close() {
        appMemory.hasSeenElectionLiveWhatsNewScreen(true)
        Task { await AnalyticsService().send(originatingScreen: "ElectionLiveWhatsNew", action: "dismissed") }
        dismiss()
    }

    private func featureItem(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accentGreen)
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

// MARK: - Confirma Key

extension IntroducingElectionLiveView {

    /// Colors of the real CONFIRMA key.
    enum ConfirmaKey {
        static let face = Color(red: 0.37, green: 0.62, blue: 0.34)
        static let edge = Color(red: 0.24, green: 0.44, blue: 0.22)
        static let ink = Color(red: 0.09, green: 0.21, blue: 0.09)
        static let depth: CGFloat = 6

        /// The ballot machine's confirmation beep, through the system sound API instead of
        /// an audio player: it respects the silent switch, mixes with whatever is playing,
        /// and never touches the app's `.playback` session, so an episode keeps going.
        private static let soundID: SystemSoundID? = {
            guard let url = Bundle.main.url(forResource: "urna_confirma", withExtension: "caf") else {
                return nil
            }
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else {
                return nil
            }
            return id
        }()

        static func playSound() {
            guard let soundID else { return }
            AudioServicesPlaySystemSound(soundID)
        }
    }

    /// A physical key: the face sits on a darker edge and sinks into it while pressed.
    struct ConfirmaKeyStyle: ButtonStyle {

        func makeBody(configuration: Configuration) -> some View {
            let depth = configuration.isPressed ? 1 : ConfirmaKey.depth
            configuration.label
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(ConfirmaKey.face, in: .rect(cornerRadius: 12))
                .offset(y: ConfirmaKey.depth - depth)
                .background(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ConfirmaKey.edge)
                        .offset(y: ConfirmaKey.depth)
                }
                .padding(.bottom, ConfirmaKey.depth)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }
    }

    struct ConfirmaKeyLabel: View {

        var body: some View {
            VStack(spacing: 8) {
                Text("CONFIRMA")
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .tracking(1)
                BrailleView(text: "CONFIRMA")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(ConfirmaKey.ink)
        }
    }

    /// Only the raised dots of each cell, like the embossing on the key. Letters a to z;
    /// anything else is left blank.
    struct BrailleView: View {

        let text: String

        /// Dots 1-2-3 run down the left column, 4-5-6 down the right.
        private static let letters: [Character: Set<Int>] = [
            "A": [1], "B": [1, 2], "C": [1, 4], "D": [1, 4, 5], "E": [1, 5],
            "F": [1, 2, 4], "G": [1, 2, 4, 5], "H": [1, 2, 5], "I": [2, 4], "J": [2, 4, 5],
            "K": [1, 3], "L": [1, 2, 3], "M": [1, 3, 4], "N": [1, 3, 4, 5], "O": [1, 3, 5],
            "P": [1, 2, 3, 4], "Q": [1, 2, 3, 4, 5], "R": [1, 2, 3, 5], "S": [2, 3, 4], "T": [2, 3, 4, 5],
            "U": [1, 3, 6], "V": [1, 2, 3, 6], "W": [2, 4, 5, 6], "X": [1, 3, 4, 6], "Y": [1, 3, 4, 5, 6],
            "Z": [1, 3, 5, 6]
        ]

        private let dot: CGFloat = 4.5
        private let dotSpacing: CGFloat = 2.5

        var body: some View {
            HStack(spacing: 7) {
                ForEach(Array(text.uppercased().enumerated()), id: \.offset) { _, letter in
                    cell(Self.letters[letter] ?? [])
                }
            }
        }

        private func cell(_ dots: Set<Int>) -> some View {
            HStack(spacing: dotSpacing) {
                column(dots, numbers: [1, 2, 3])
                column(dots, numbers: [4, 5, 6])
            }
        }

        private func column(_ dots: Set<Int>, numbers: [Int]) -> some View {
            VStack(spacing: dotSpacing) {
                ForEach(numbers, id: \.self) { number in
                    Circle()
                        .frame(width: dot, height: dot)
                        .opacity(dots.contains(number) ? 1 : 0)
                }
            }
        }
    }
}

// MARK: - Keypad Pattern

extension IntroducingElectionLiveView {

    /// Mini ballot machine keypads tiled behind the header: digits 1 to 9 with 0 under the 8,
    /// and BRANCO, CORRIGE and CONFIRMA in their real colors. A dot on each key hints at the
    /// braille. Few, large and faint, and gone behind the photos and the title: smaller or
    /// denser keypads turn into noise.
    struct KeypadPatternView: View {

        private static let key = CGSize(width: 14, height: 10)
        private static let actionWidth: CGFloat = 22
        private static let gap: CGFloat = 3
        private static let padding: CGFloat = 4
        private static let angle = Angle.degrees(-12)
        private static let scale: CGFloat = 1.35
        private static let spacing = CGSize(width: 34, height: 26)

        private static var keypadSize: CGSize {
            CGSize(
                width: padding * 2 + key.width * 3 + actionWidth + gap * 3,
                height: padding * 2 + key.height * 4 + gap * 3
            )
        }

        var body: some View {
            Canvas { context, size in
                let tile = Self.keypadSize
                let step = CGSize(width: tile.width + Self.spacing.width, height: tile.height + Self.spacing.height)
                // Rotated around the center, so the grid overshoots to cover the corners.
                let reach = hypot(size.width, size.height) / 2 / Self.scale
                context.translateBy(x: size.width / 2, y: size.height / 2)
                context.scaleBy(x: Self.scale, y: Self.scale)
                context.rotate(by: Self.angle)

                var row = 0
                var y = -reach
                while y < reach {
                    var x = -reach + (row.isMultiple(of: 2) ? 0 : step.width / 2)
                    while x < reach {
                        drawKeypad(in: &context, at: CGPoint(x: x, y: y))
                        x += step.width
                    }
                    y += step.height
                    row += 1
                }
            }
            .opacity(0.55)
            // Clear behind the photos and the title, visible toward the edges.
            .mask {
                RadialGradient(
                    colors: [.clear, .clear, .white],
                    center: UnitPoint(x: 0.5, y: 0.45),
                    startRadius: 0,
                    endRadius: 230
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

        private func drawKeypad(in context: inout GraphicsContext, at origin: CGPoint) {
            let key = Self.key, gap = Self.gap, padding = Self.padding
            let frame = CGRect(origin: origin, size: Self.keypadSize)
            context.stroke(
                Path(roundedRect: frame, cornerRadius: 5),
                with: .color(.white.opacity(0.08)),
                lineWidth: 0.8
            )

            func keyRect(column: Int, row: Int, width: CGFloat = key.width, rows: Int = 1) -> CGRect {
                CGRect(
                    x: frame.minX + padding + CGFloat(column) * (key.width + gap),
                    y: frame.minY + padding + CGFloat(row) * (key.height + gap),
                    width: width,
                    height: key.height * CGFloat(rows) + gap * CGFloat(rows - 1)
                )
            }

            let digits: [(String, Int, Int)] = [
                ("1", 0, 0), ("2", 1, 0), ("3", 2, 0),
                ("4", 0, 1), ("5", 1, 1), ("6", 2, 1),
                ("7", 0, 2), ("8", 1, 2), ("9", 2, 2),
                ("0", 1, 3)
            ]
            for (digit, column, row) in digits {
                let rect = keyRect(column: column, row: row)
                context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(.black.opacity(0.18)))
                context.draw(
                    Text(digit)
                        .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.22)),
                    at: CGPoint(x: rect.minX + 4, y: rect.midY)
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: rect.maxX - 4.5, y: rect.minY + 2.5, width: 1.6, height: 1.6)),
                    with: .color(.white.opacity(0.18))
                )
            }

            // CONFIRMA is a lighter green, or it'd vanish into the background.
            let actions: [(Color, Double, Int, Int)] = [
                (.white, 0.2, 0, 1),
                (Color(red: 0.88, green: 0.44, blue: 0.20), 0.2, 1, 1),
                (Color(red: 0.55, green: 0.85, blue: 0.45), 0.3, 2, 2)
            ]
            for (color, opacity, row, rows) in actions {
                let rect = keyRect(column: 3, row: row, width: Self.actionWidth, rows: rows)
                context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(color.opacity(opacity)))
            }
        }
    }
}

// MARK: - Clash Hero

extension IntroducingElectionLiveView {

    /// Lula and Flávio charge at each other, clash and bounce back; every clash moves the
    /// "TOTALIZADO" bar one step, like a new TSE file, until 100% and a fresh start. One
    /// sequential `Task` drives it, like the share clip hero, so the pieces never drift
    /// apart. With Reduce Motion, it's a still frame.
    struct ClashHeroView: View {

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        /// Distance from the center to each candidate's center.
        @State private var gap: CGFloat = Self.restingGap
        @State private var squash: CGFloat = 1
        @State private var tilt: Double = 0
        @State private var impacts = 0
        @State private var counted: Double = 0

        private static let size: CGFloat = 60
        private static let restingGap: CGFloat = 78
        /// The circles touch here.
        private static let contactGap: CGFloat = size / 2 - 1
        private static let steps: [Double] = [0.24, 0.46, 0.64, 0.79, 0.9, 0.97, 1.0]
        private static let yellow = Color(red: 1, green: 0.84, blue: 0)

        var body: some View {
            VStack(spacing: 14) {
                ZStack {
                    impactFlash
                    // Tilted in place, then moved: rotating after the offset would swing
                    // them around the center of the header. Each leans into the clash.
                    candidate(13, towards: .trailing)
                        .rotationEffect(.degrees(tilt))
                        .offset(x: -gap)
                    candidate(22, towards: .leading)
                        .rotationEffect(.degrees(-tilt))
                        .offset(x: gap)
                }
                .frame(height: Self.size)

                counter
            }
            .task(id: reduceMotion) {
                if reduceMotion {
                    gap = Self.restingGap
                    counted = 0.62
                } else {
                    await runLoop()
                }
            }
        }

        /// Squashes against the side it hits.
        private func candidate(_ number: Int, towards side: UnitPoint) -> some View {
            Image("ElectionCandidate\(number)")
                .resizable()
                .scaledToFill()
                .frame(width: Self.size, height: Self.size, alignment: .top)
                .clipShape(.circle)
                .overlay {
                    Circle().strokeBorder(.white, lineWidth: 2.5)
                }
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                .scaleEffect(x: squash, y: 2 - squash, anchor: side)
        }

        /// A ring bursting out of the point of contact on every clash.
        private var impactFlash: some View {
            Circle()
                .strokeBorder(Self.yellow, lineWidth: 3)
                .frame(width: 44, height: 44)
                .keyframeAnimator(initialValue: FlashValues(), trigger: impacts) { ring, values in
                    ring
                        .scaleEffect(values.scale)
                        .opacity(values.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        LinearKeyframe(0.3, duration: 0.01)
                        CubicKeyframe(1.9, duration: 0.45)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1, duration: 0.01)
                        CubicKeyframe(0, duration: 0.45)
                    }
                }
        }

        private var counter: some View {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("\(Int(counted * 100))% TOTALIZADO")
                        .font(.caption)
                        .fontWeight(.heavy)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(.white)
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.22))
                    Capsule()
                        .fill(Self.yellow)
                        .frame(width: max(10, 200 * counted))
                }
                .frame(width: 200, height: 8)
            }
        }

        private func runLoop() async {
            while !Task.isCancelled {
                for step in Self.steps {
                    // Charge.
                    withAnimation(.easeIn(duration: 0.3)) {
                        gap = Self.contactGap
                        tilt = 6
                    }
                    try? await Task.sleep(for: .seconds(0.3))
                    guard !Task.isCancelled else { return }

                    // Clash: squash, burst, and the count moves.
                    impacts += 1
                    withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) {
                        squash = 0.92
                    }
                    withAnimation(.easeInOut(duration: 0.45)) {
                        counted = step
                    }
                    try? await Task.sleep(for: .seconds(0.12))
                    guard !Task.isCancelled else { return }

                    // Bounce back.
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) {
                        gap = Self.restingGap
                        squash = 1
                        tilt = 0
                    }
                    try? await Task.sleep(for: .seconds(1.1))
                    guard !Task.isCancelled else { return }
                }

                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.35)) {
                    counted = 0
                }
                try? await Task.sleep(for: .seconds(0.6))
            }
        }

        private struct FlashValues {
            var scale: CGFloat = 0.3
            var opacity: Double = 0
        }
    }
}

// MARK: - Preview

#Preview("As Standalone View") {
    IntroducingElectionLiveView(appMemory: AppPersistentMemory.shared)
}

#Preview("As Sheet") {
    VStack {
        Text("Stuff")
    }
    .sheet(isPresented: .constant(true)) {
        IntroducingElectionLiveView(appMemory: AppPersistentMemory.shared)
    }
}
