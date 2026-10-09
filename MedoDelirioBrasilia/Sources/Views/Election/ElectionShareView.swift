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
    /// The results screen's background goes into the picture too.
    var theme: ElectionFinalTheme? = nil
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
    /// Called with the activity picked once a share completes, right before this screen
    /// closes, so the screen underneath can confirm it.
    let onShared: (UIActivity.ActivityType?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var format: ElectionShareFormat = .square
    @State private var shareItem: ImageShareItemSource?
    @State private var isRendering = false
    @State private var copiedHandle = false

    private static let instagramHandle = "@medoedelirioembrasiliapodcast"

    /// From the tap until the share sheet closes: the render and the sheet's own startup
    /// together take a second or two.
    private var isPreparingShare: Bool {
        isRendering || shareItem != nil
    }

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
                    ElectionShareCard(round: snapshot.round, state: snapshot.state, format: format, theme: snapshot.theme)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Prévia da imagem, formato \(format.title)")
                }
                .animation(.snappy, value: format)

                if format == .stories {
                    tagCallout
                }

                Button {
                    isRendering = true
                    Task {
                        // Rendering blocks the main thread, so give the spinner a frame to
                        // show up first. It keeps spinning on its own while the render runs.
                        try? await Task.sleep(for: .milliseconds(50))
                        if let image = ElectionShareCard.render(round: snapshot.round, state: snapshot.state, format: format, theme: snapshot.theme) {
                            shareItem = ImageShareItemSource(image: image, title: shareTitle)
                        }
                        isRendering = false
                    }
                } label: {
                    // The label stays in the layout while the spinner shows, so the button
                    // keeps its height.
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                        .opacity(isPreparingShare ? 0 : 1)
                        .overlay {
                            if isPreparingShare {
                                ProgressView()
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .spacing(.xxSmall))
                }
                .electionButtonStyle(prominent: true)
                .disabled(isPreparingShare)
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
            .shareSheet(item: $shareItem, activityItems: { [$0] }) { _, activityType, completed in
                guard completed else { return }
                onShared(activityType)
                dismiss()
            }
            .task(id: copiedHandle) {
                guard copiedHandle else { return }
                try? await Task.sleep(for: .seconds(2))
                copiedHandle = false
            }
        }
    }

    /// Asks people posting to Stories to tag the podcast. Tapping the handle copies it, since
    /// typing it into Instagram's mention sticker is a chore.
    private var tagCallout: some View {
        VStack(spacing: .spacing(.small)) {
            Text("Vai postar nos Stories? Marca o podcast!")
                .font(.subheadline.weight(.semibold))

            Button {
                UIPasteboard.general.string = Self.instagramHandle
                HapticFeedback.success()
                copiedHandle = true
            } label: {
                // The handle's label stays in the layout underneath, so the shorter
                // checkmark doesn't shrink the button.
                Label(Self.instagramHandle, systemImage: "doc.on.doc")
                    .hidden()
                    .overlay {
                        Label(
                            copiedHandle ? "Copiado" : Self.instagramHandle,
                            systemImage: copiedHandle ? "checkmark" : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                    }
                    .font(.subheadline)
            }
            .tint(ElectionResultsPalette.accent)
            .accessibilityHint("Copia o nome da conta do podcast no Instagram")
        }
        .multilineTextAlignment(.center)
        .padding(.vertical, .spacing(.small))
    }
}

// MARK: - Card

/// A picture of the current count in the Live Activity's colors, with the source and the
/// app's name. Stories keep the top and bottom clear, where Instagram draws its own controls.
struct ElectionShareCard: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let format: ElectionShareFormat
    var theme: ElectionFinalTheme? = nil

    @MainActor
    static func render(
        round: Int,
        state: ElectionActivityAttributes.ContentState,
        format: ElectionShareFormat,
        theme: ElectionFinalTheme? = nil
    ) -> UIImage? {
        let renderer = ImageRenderer(content: ElectionShareCard(round: round, state: state, format: format, theme: theme))
        renderer.scale = 3
        return renderer.uiImage
    }

    private var heading: String {
        state.isFinal ? "APURAÇÃO · PRESIDENTE · \(round)º TURNO · RESULTADO" : "APURAÇÃO · PRESIDENTE · \(round)º TURNO"
    }

    /// Stories are too narrow for the final heading on one line, and letting it wrap left
    /// "· RESULTADO" on its own, so it breaks before "RESULTADO" instead.
    private var storiesHeading: String {
        state.isFinal ? "APURAÇÃO · PRESIDENTE · \(round)º TURNO\nRESULTADO" : heading
    }

    private var time: String {
        state.updatedAtDate.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        ZStack {
            background

            switch format {
            case .square: square
            case .stories: stories
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // A picture has a fixed size: the same text whatever size the person reads at, in
        // the preview and in the rendered image alike.
        .dynamicTypeSize(.large)
        .frame(width: format.size.width, height: format.size.height)
    }

    /// Same colors as the results screen: green, red for the celebration, and the night sky,
    /// every star already out, for the comfort. The keypad pattern would crowd the stars.
    @ViewBuilder
    private var background: some View {
        switch theme {
        case nil:
            gradient(ElectionResultsPalette.header, ElectionResultsPalette.body)
            IntroducingElectionLiveView.KeypadPatternView()
        case .celebration:
            gradient(ElectionResultsPalette.celebrationTop, ElectionResultsPalette.celebrationBottom)
            IntroducingElectionLiveView.KeypadPatternView()
        case .comfort:
            gradient(ElectionResultsPalette.nightTop, ElectionResultsPalette.nightBottom)
            ElectionNightSkyView(isStill: true, guidingStarPosition: guidingStarPosition)
        }
    }

    /// Beside the right photo on the square. On Stories, the photo itself carries it
    /// (`candidates`), so it stays on its corner however the layout falls.
    private var guidingStarPosition: UnitPoint? {
        switch format {
        case .square: UnitPoint(x: 0.93, y: 0.22)
        case .stories: nil
        }
    }

    /// The runner-up's photo on Stories, for the comfort: that's Lula when it's shown.
    private func carriesGuidingStar(_ candidate: ElectionActivityAttributes.Candidate) -> Bool {
        theme == .comfort && format == .stories && candidate.id == state.candidates.dropFirst().first?.id
    }

    private func gradient(_ top: Color, _ bottom: Color) -> some View {
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Flexible spacers between the blocks, so the content fills the square whether names
    /// take one line or two, instead of bunching up in the middle.
    private var square: some View {
        VStack(spacing: 0) {
            Text(heading)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 12)

            candidates(photoSize: 84, percentSize: 30, spacing: 8)

            Spacer(minLength: 12)

            counted(fontSize: 15)
                .padding(.horizontal, 12)

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

    /// Related blocks stay together, and flexible spacers split whatever height is left
    /// between the groups, so the card breathes without spilling past the safe area. Roomier
    /// than the square inside each block too: Stories are seen full screen.
    private var stories: some View {
        VStack(spacing: 0) {
            Text(storiesHeading)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Spacer(minLength: 32)

            candidates(photoSize: 112, percentSize: 34, spacing: 12)

            Spacer(minLength: 32)

            counted(fontSize: 18, spacing: 12)

            Spacer(minLength: 32)

            // The podcast's logo signs the picture, next to the source and the app's credit.
            HStack(alignment: .center, spacing: 12) {
                Image("podcast_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Fonte: TSE · Atualizado às \(time)")
                    Text("Criado com o app Medo e Delírio iOS")
                }
                .font(.system(size: 12, weight: .medium))
                // One line each, shrinking a little rather than wrapping next to the logo.
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 28)
        // Instagram covers roughly the top and bottom 13% (250 px of 1920) with its own controls.
        .padding(.vertical, 84)
    }

    private func candidates(photoSize: CGFloat, percentSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(state.candidates.prefix(2))) { candidate in
                VStack(spacing: spacing) {
                    ElectionCandidatePhoto(number: candidate.number, colorHex: candidate.colorHex, size: photoSize)
                        .overlay(alignment: .topTrailing) {
                            if carriesGuidingStar(candidate) {
                                // Just outside the circle, at 45°, over the frame's corner.
                                ElectionGuidingStarView()
                                    .offset(x: ElectionGuidingStarView.size / 4, y: -ElectionGuidingStarView.size / 4)
                            }
                        }
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

    private func counted(fontSize: CGFloat, spacing: CGFloat = 6) -> some View {
        VStack(spacing: spacing) {
            Text("\(ElectionResultsFormat.percent(state.sectionsCountedPercent)) TOTALIZADO")
                .font(.system(size: fontSize, weight: .bold))
                .monospacedDigit()
            ElectionResultsBar(fraction: state.sectionsCountedPercent / 100, color: ElectionResultsPalette.bar)
                .frame(height: fontSize * 0.5)
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
    ElectionShareView(snapshot: ElectionShareSnapshot(round: 1, state: previewState)) { _ in }
}

#Preview("Square Card") {
    ElectionShareCard(round: 1, state: previewState, format: .square)
}

#Preview("Stories Card") {
    ElectionShareCard(round: 1, state: previewState, format: .stories)
}

#Preview("Square Card, Comfort") {
    ElectionShareCard(round: 1, state: previewState, format: .square, theme: .comfort)
}

#Preview("Stories Card, Comfort") {
    ElectionShareCard(round: 1, state: previewState, format: .stories, theme: .comfort)
}

#Preview("Stories Card, Celebration") {
    ElectionShareCard(round: 1, state: previewState, format: .stories, theme: .celebration)
}
