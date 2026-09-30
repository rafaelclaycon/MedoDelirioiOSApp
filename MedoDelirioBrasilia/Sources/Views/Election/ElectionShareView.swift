//
//  ElectionShareView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 29/09/26.
//

import SwiftUI

/// The count at the moment someone taps "Compartilhar Imagem", so the preview doesn't change
/// while they pick a format.
struct ElectionShareSnapshot: Identifiable {

    let id = UUID()
    let round: Int
    let state: ElectionActivityAttributes.ContentState
}

enum ElectionShareFormat: String, CaseIterable, Identifiable {

    /// Feed posts and chats.
    case square
    /// Instagram and WhatsApp stories.
    case stories

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: "Quadrada"
        case .stories: "Stories (9:16)"
        }
    }

    /// Rendered at 3x: 1080 × 1080 and 1080 × 1920.
    var size: CGSize {
        switch self {
        case .square: CGSize(width: 360, height: 360)
        case .stories: CGSize(width: 360, height: 640)
        }
    }
}

/// Shows exactly what gets shared, a picture of the count as it is now, and lets people pick
/// the square or the stories format before sharing.
struct ElectionShareView: View {

    let snapshot: ElectionShareSnapshot

    @Environment(\.dismiss) private var dismiss

    @State private var format: ElectionShareFormat = .square
    @State private var shareItem: ImageShareItemSource?

    private var explanation: String {
        let time = snapshot.state.updatedAtDate.formatted(date: .omitted, time: .shortened)
        if snapshot.state.isFinal {
            return "Uma imagem com o resultado final da apuração, divulgado pelo TSE às \(time)."
        }
        let counted = ElectionResultsFormat.percent(snapshot.state.sectionsCountedPercent)
        return "Uma imagem da apuração como está agora: \(counted) totalizado, atualizado às \(time). Ela não muda depois de compartilhada."
    }

    /// The share sheet's header, e.g. "Apuração · Presidente · 65,57% totalizado".
    private var shareTitle: String {
        if snapshot.state.isFinal {
            return "Resultado da Apuração · Presidente · \(snapshot.round)º turno"
        }
        return "Apuração · Presidente · \(ElectionResultsFormat.percent(snapshot.state.sectionsCountedPercent)) totalizado"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: .spacing(.large)) {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Formato", selection: $format) {
                    ForEach(ElectionShareFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                GeometryReader { proxy in
                    let size = format.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    ElectionShareCard(round: snapshot.round, state: snapshot.state, format: format)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Prévia da imagem, formato \(format.title)")
                }
                .animation(.snappy, value: format)

                Button {
                    if let image = ElectionShareCard.render(round: snapshot.round, state: snapshot.state, format: format) {
                        shareItem = ImageShareItemSource(image: image, title: shareTitle)
                    }
                } label: {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing(.xxSmall))
                }
                .electionButtonStyle(prominent: true)
            }
            .padding(.spacing(.large))
            .navigationTitle("Compartilhar Imagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            .shareSheet(item: $shareItem, activityItems: { [$0] })
        }
    }
}

// MARK: - Card

/// A picture of the current count in the Live Activity's colors, with the source and the
/// app's name. Stories keep the top and bottom clear, where Instagram draws its own controls.
struct ElectionShareCard: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let format: ElectionShareFormat

    @MainActor
    static func render(round: Int, state: ElectionActivityAttributes.ContentState, format: ElectionShareFormat) -> UIImage? {
        let renderer = ImageRenderer(content: ElectionShareCard(round: round, state: state, format: format))
        renderer.scale = 3
        return renderer.uiImage
    }

    private var heading: String {
        state.isFinal ? "APURAÇÃO · PRESIDENTE · \(round)º TURNO · RESULTADO" : "APURAÇÃO · PRESIDENTE · \(round)º TURNO"
    }

    private var time: String {
        state.updatedAtDate.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ElectionResultsPalette.header, ElectionResultsPalette.body],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            IntroducingElectionLiveView.KeypadPatternView()

            switch format {
            case .square: square
            case .stories: stories
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .frame(width: format.size.width, height: format.size.height)
    }

    /// Flexible spacers between the blocks, so the content fills the square whether names
    /// take one line or two, instead of bunching up in the middle.
    private var square: some View {
        VStack(spacing: 0) {
            Text(heading)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 12)

            candidates(photoSize: 84, percentSize: 30)

            Spacer(minLength: 12)

            VStack(spacing: 10) {
                counted(fontSize: 15)
                    .padding(.horizontal, 12)
                finalMessage(fontSize: 14)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                appBadge(iconSize: 24, fontSize: 12)
                Spacer()
                Text("Fonte: TSE · \(time)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    private var stories: some View {
        VStack(spacing: 22) {
            appBadge(iconSize: 30, fontSize: 14)

            Text(heading)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            candidates(photoSize: 112, percentSize: 34)

            counted(fontSize: 18)

            finalMessage(fontSize: 17)

            Text("Fonte: TSE · Atualizado às \(time)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 28)
        // Instagram covers roughly the top and bottom 14% with its own controls.
        .padding(.vertical, 90)
    }

    private func candidates(photoSize: CGFloat, percentSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(state.candidates.prefix(2))) { candidate in
                VStack(spacing: 8) {
                    ElectionCandidatePhoto(number: candidate.number, colorHex: candidate.colorHex, size: photoSize)
                    Text(ElectionResultsFormat.percent(candidate.percent))
                        .font(.system(size: percentSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(candidate.name)
                        .font(.system(size: percentSize * 0.4, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func counted(fontSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text("\(ElectionResultsFormat.percent(state.sectionsCountedPercent)) TOTALIZADO")
                .font(.system(size: fontSize, weight: .bold))
                .monospacedDigit()
            ElectionResultsBar(fraction: state.sectionsCountedPercent / 100, color: ElectionResultsPalette.bar)
                .frame(height: fontSize * 0.5)
        }
    }

    @ViewBuilder
    private func finalMessage(fontSize: CGFloat) -> some View {
        if state.isFinal, let finalMessage = state.finalMessage {
            Text(finalMessage)
                .font(.system(size: fontSize, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    private func appBadge(iconSize: CGFloat, fontSize: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image("IconePadrao")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: iconSize * 0.25))
            Text("Medo e Delírio em Brasília")
                .font(.system(size: fontSize, weight: .bold))
        }
    }
}

// MARK: - Preview

private let previewState = ElectionActivityAttributes.ContentState(
    sectionsCountedPercent: 65.57,
    isFinal: false,
    updatedAt: 1_790_277_154,
    candidates: [
        .init(number: 13, name: "LULA", party: "PT", percent: 47.12, status: .counting, colorHex: nil),
        .init(number: 22, name: "FLAVIO BOLSONARO", party: "PL", percent: 38.45, status: .counting, colorHex: nil)
    ]
)

#Preview("Share Screen") {
    ElectionShareView(snapshot: ElectionShareSnapshot(round: 1, state: previewState))
}

#Preview("Square Card") {
    ElectionShareCard(round: 1, state: previewState, format: .square)
}

#Preview("Stories Card") {
    ElectionShareCard(round: 1, state: previewState, format: .stories)
}
