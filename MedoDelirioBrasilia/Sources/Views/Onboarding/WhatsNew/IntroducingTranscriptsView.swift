//
//  IntroducingTranscriptsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/03/26.
//

import SwiftUI

struct IntroducingTranscriptsView: View {

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
                Color(red: 0.15, green: 0.08, blue: 0.02),
                Color(red: 0.25, green: 0.14, blue: 0.04),
                Color(red: 0.35, green: 0.20, blue: 0.06)
            ]
        } else {
            return [
                Color(red: 0.90, green: 0.55, blue: 0.10),
                Color(red: 0.95, green: 0.65, blue: 0.20),
                Color(red: 1.00, green: 0.75, blue: 0.30)
            ]
        }
    }

    private let accentAmber = Color(red: 0.92, green: 0.60, blue: 0.15)

    var body: some View {
        NavigationView {
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

                        TranscriptKaraokeView(colorScheme: colorScheme)

                        VStack(spacing: 8) {
                            Spacer()

                            Text("NOVIDADE DOS EPISÓDIOS")
                                .font(.footnote)
                                .bold()
                                .foregroundStyle(
                                    colorScheme == .dark
                                        ? Color.primary.opacity(0.85)
                                        : Color(red: 0.35, green: 0.18, blue: 0.0)
                                )

                            Text("Transcrições")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 12, x: 0, y: 2)

//                            Text("Ele disse isso mesmo? Agora você pode conferir.")
//                                .font(.headline)
//                                .foregroundStyle(
//                                    colorScheme == .dark
//                                        ? Color.primary.opacity(0.85)
//                                        : Color(red: 0.35, green: 0.18, blue: 0.0)
//                                )
//                                .multilineTextAlignment(.center)

                            Spacer()
                                .frame(height: 16)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 320)
                    .clipped()

                    VStack(alignment: .leading, spacing: 24) {
                        featureItem(
                            icon: "text.quote",
                            title: "Leia Enquanto Ouve",
                            message: "Acompanhe a transcrição em tempo real no player."
                        )

                        featureItem(
                            icon: "magnifyingglass",
                            title: "Busque em Todos os Episódios",
                            message: "Encontre qualquer trecho do podcast em segundos."
                        )

                        featureItem(
                            icon: "clock.arrow.2.circlepath",
                            title: "Sempre Atualizado",
                            message: "Novos episódios são transcritos automaticamente."
                        )
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
                appMemory.hasSeenTranscriptsWhatsNewScreen(true)
                dismiss()
            } label: {
                Text("Bora!")
                    .font(.headline)
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)
        } else {
            Button {
                appMemory.hasSeenTranscriptsWhatsNewScreen(true)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Bora!")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .largeRoundedRectangleBorderedProminent(colored: accentAmber)
        }
    }

    private func featureItem(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accentAmber)
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

// MARK: - Transcript Karaoke Hero

extension IntroducingTranscriptsView {

    struct TranscriptKaraokeView: View {

        let colorScheme: ColorScheme

        private struct Line {
            let text: String
            let highlightWord: String?
        }

        private static let lines: [Line] = [
            Line(text: "Meu queridíssimo Pedro Daltro.", highlightWord: "Pedro Daltro"),
            Line(text: "E é por essas e outras que todo otimismo é em vão.", highlightWord: "otimismo é em vão"),
            Line(text: "Vocês vão apodrecer na cadeia.", highlightWord: "apodrecer na cadeia"),
            Line(text: "E a gente fica se perguntando, né?", highlightWord: nil),
            Line(text: "Na política não basta ser honesto,", highlightWord: "honesto"),
            Line(text: "E aí, a casa começa a cair geral.", highlightWord: "a casa começa a cair"),
            Line(text: "Direitos humanos para humanos direitos.", highlightWord: "humanos direitos"),
            Line(text: "Não façam essa baixaria que a imprensa vai comer.", highlightWord: nil),
            Line(text: "Então, gente, a coisa deu uma murchada.", highlightWord: "murchada"),
            Line(text: "E Guedes, o Chicago Boy, queria que fosse pra sempre.", highlightWord: "Chicago Boy"),
            Line(text: "Eu acho que tem uma coisa muito clara aí.", highlightWord: nil),
            Line(text: "E a gente não duvida é mais de nada.", highlightWord: nil),
        ]

        private static let dwellSeconds: TimeInterval = 3.5

        var body: some View {
            TimelineView(.periodic(from: .now, by: Self.dwellSeconds)) { timeline in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate / Self.dwellSeconds)
                let count = Self.lines.count
                let currentIdx = tick % count
                let prevIdx = (currentIdx - 1 + count) % count
                let nextIdx = (currentIdx + 1) % count

                VStack(alignment: .leading, spacing: 16) {
                    Spacer()

                    cueLine(Self.lines[prevIdx], role: .surrounding)
                        .id("prev-\(prevIdx)")

                    cueLine(Self.lines[currentIdx], role: .active)
                        .id("current-\(currentIdx)")

                    cueLine(Self.lines[nextIdx], role: .surrounding)
                        .id("next-\(nextIdx)")

                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut(duration: 0.35), value: currentIdx)
            }
            .allowsHitTesting(false)
        }

        private enum CueRole {
            case active
            case surrounding
        }

        @ViewBuilder
        private func cueLine(_ line: Line, role: CueRole) -> some View {
            let isActive = role == .active
            let hasHighlight = isActive && line.highlightWord != nil

            let highlightColor: Color = colorScheme == .dark
                ? Color(red: 0.95, green: 0.65, blue: 0.15).opacity(0.7)
                : Color(red: 0.30, green: 0.12, blue: 0.0).opacity(0.55)

            HStack(alignment: .top, spacing: 4) {
                if hasHighlight {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                        .transition(.opacity)
                }

                styledText(line, role: role, highlightColor: highlightColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isActive ? 1.0 : 0.3)
        }

        private func styledText(_ line: Line, role: CueRole, highlightColor: Color) -> Text {
            let isActive = role == .active
            let baseFont: Font = isActive ? .title3.weight(.semibold) : .callout
            let baseColor: Color = .white.opacity(isActive ? 0.9 : 0.6)

            guard isActive,
                  let word = line.highlightWord,
                  let range = line.text.range(of: word) else {
                return Text(line.text)
                    .font(baseFont)
                    .foregroundColor(baseColor)
            }

            let before = String(line.text[line.text.startIndex..<range.lowerBound])
            let match = String(line.text[range])
            let after = String(line.text[range.upperBound..<line.text.endIndex])

            var highlighted = AttributedString(match)
            highlighted.font = isActive ? .title3.weight(.bold) : baseFont
            highlighted.foregroundColor = .white
            highlighted.backgroundColor = highlightColor

            return Text(before).font(baseFont).foregroundColor(baseColor)
                + Text(highlighted)
                + Text(after).font(baseFont).foregroundColor(baseColor)
        }
    }
}

// MARK: - Preview

#Preview("As Standalone View") {
    IntroducingTranscriptsView(appMemory: AppPersistentMemory.shared)
}

#Preview("As Sheet") {
    VStack {
        Text("Stuff")
        Text("Stuff")
        Text("Stuff")
    }
    .sheet(isPresented: .constant(true)) {
        IntroducingTranscriptsView(appMemory: AppPersistentMemory.shared)
    }
}
