//
//  ShareClipVideoFrameView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/02/26.
//

import SwiftUI

// MARK: - Layout

/// Computes absolute positions and sizes for the video frame content.
/// Shared between the SwiftUI view (static rendering) and the generator
/// (CALayer scrubber animation) to guarantee pixel-perfect alignment.
struct ShareClipVideoLayout {

    let videoSize: CGSize
    /// When true, the frame uses a distinct layout: a compact top-left header
    /// (artwork with title/date beside it) and a large transcript region in the
    /// middle. When false, the classic centered layout is used, unchanged.
    var includesTranscript: Bool = false

    private var isPortrait: Bool { videoSize.height > videoSize.width }
    private var isLandscape: Bool { videoSize.width > videoSize.height }

    var horizontalPadding: CGFloat { videoSize.width * 0.1 }

    var artworkSize: CGFloat {
        if isPortrait { return videoSize.width * 0.55 }
        if isLandscape { return min(videoSize.height * 0.45, videoSize.width * 0.28) }
        return videoSize.width * 0.40
    }

    var artworkCornerRadius: CGFloat { artworkSize * 0.06 }

    var titleSpacing: CGFloat { videoSize.height * 0.05 }
    var dateSpacing: CGFloat { videoSize.height * 0.025 }

    var titleFontSize: CGFloat {
        if isLandscape { return 44 }
        return 40
    }

    var dateFontSize: CGFloat { titleFontSize * 0.7 }

    var trackCornerRadius: CGFloat { trackFrame.height / 2 }

    /// The progress bar track rectangle in the video's coordinate system.
    var trackFrame: CGRect {
        let padding = horizontalPadding
        let height: CGFloat = max(videoSize.height * 0.005, 6)
        let width = videoSize.width - 2 * padding
        let y: CGFloat
        if isPortrait { y = videoSize.height * 0.65 }
        else if isLandscape { y = videoSize.height * 0.78 }
        else { y = videoSize.height * 0.79 }
        return CGRect(x: padding, y: y, width: width, height: height)
    }

    var timestampFontSize: CGFloat { max(videoSize.width * 0.028, 22) }
    var timestampHeight: CGFloat { timestampFontSize * 1.3 }
    var timestampY: CGFloat { trackFrame.origin.y - timestampHeight - videoSize.height * 0.012 }
    var timestampLabelWidth: CGFloat { videoSize.width * 0.22 }

    /// Anchors the clip's start time within the full episode, left-aligned above the track's leading edge.
    var leadingTimestampFrame: CGRect {
        CGRect(x: trackFrame.origin.x, y: timestampY, width: timestampLabelWidth, height: timestampHeight)
    }

    /// Counts down the clip's remaining time, right-aligned above the track's trailing edge.
    var trailingTimestampFrame: CGRect {
        CGRect(x: trackFrame.maxX - timestampLabelWidth, y: timestampY, width: timestampLabelWidth, height: timestampHeight)
    }

    /// Height of the region above the progress track and its timestamps. The
    /// artwork/title/date block is laid out within this region so it never
    /// collides with the track, however long the title wraps.
    var contentAreaHeight: CGFloat { timestampY }

    /// A deliberate, fixed gap between the frame's top edge and the artwork.
    /// Kept independent of title length so there's always visible breathing
    /// room up top — the leftover space below (before the track) is what
    /// flexes with shorter or longer titles.
    var contentTopPadding: CGFloat { contentAreaHeight * 0.16 }

    // MARK: - Transcript Layout

    var headerTopPadding: CGFloat { videoSize.height * (isPortrait ? 0.06 : 0.07) }
    var headerTitleFontSize: CGFloat { titleFontSize * 0.8 }
    var headerDateFontSize: CGFloat { headerTitleFontSize * 0.85 }
    var headerTextSpacing: CGFloat { headerTitleFontSize * 0.3 }

    /// Modest podcast logo on the header's left, there for branding rather
    /// than as a hero image.
    var headerLogoSize: CGFloat { min(videoSize.width, videoSize.height) * 0.12 }
    /// Gap between the logo and the title/date block beside it.
    var headerTextGap: CGFloat { videoSize.width * 0.04 }

    /// The header hugs the left edge more tightly than the rest of the frame —
    /// at the standard padding the logo + text block read as floating too far in.
    var headerLeadingPadding: CGFloat { videoSize.width * 0.06 }

    /// Header: podcast logo with title (up to two lines) and date beside it.
    /// Height is fixed to the tallest of logo and two-line text so the
    /// transcript region's top edge doesn't shift with title length.
    var headerFrame: CGRect {
        let titleLineHeight = headerTitleFontSize * 1.2
        let dateLineHeight = headerDateFontSize * 1.3
        let textHeight = 2 * titleLineHeight + headerTextSpacing + dateLineHeight
        return CGRect(
            x: headerLeadingPadding,
            y: headerTopPadding,
            width: videoSize.width - headerLeadingPadding - horizontalPadding,
            height: max(headerLogoSize, textHeight)
        )
    }

    var transcriptFontSize: CGFloat { titleFontSize * 1.25 }
    var transcriptLineHeight: CGFloat { transcriptFontSize * 1.25 }
    var transcriptMaxLines: Int {
        max(Int(transcriptFrame.height / transcriptLineHeight), 1)
    }

    /// The transcript region: everything between the header and the timestamps.
    /// Cue text is left-aligned and vertically centered within it (both in the
    /// SwiftUI preview and in the generator's pre-rendered bitmaps).
    var transcriptFrame: CGRect {
        guard includesTranscript else { return .zero }
        let top = headerFrame.maxY + videoSize.height * 0.04
        let bottom = timestampY - videoSize.height * 0.012
        return CGRect(
            x: horizontalPadding,
            y: top,
            width: videoSize.width - 2 * horizontalPadding,
            height: max(bottom - top, 0)
        )
    }
}

// MARK: - View

/// A pure SwiftUI view representing one video frame.
/// Rendered off-screen via `ImageRenderer` at the video's pixel dimensions (scale 1.0).
/// The progress bar track background is included here; the animated orange fill
/// is composited on top as a `CALayer` during video generation.
struct ShareClipVideoFrameView: View {

    let artwork: UIImage
    let episodeTitle: String
    let episodeDate: Date
    /// Where the clip starts within the full episode. Baked in statically since,
    /// unlike the trailing countdown, it never changes over the clip's duration.
    let clipStart: TimeInterval
    let videoSize: CGSize
    /// Reserves the transcript slot in the layout. The generator's static frame
    /// enables this while leaving `transcriptText` nil — the animated cue
    /// bitmaps are composited as `CALayer`s on top of the empty slot.
    var includesTranscript: Bool = false
    /// The cue text currently shown in the slot; drives the live preview's crossfade.
    var transcriptText: String? = nil

    private var layout: ShareClipVideoLayout {
        .init(videoSize: videoSize, includesTranscript: includesTranscript)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background

            if includesTranscript {
                headerRow

                transcriptSlot
            } else {
                classicContent
            }

            trackBackground

            leadingTimestampLabel
        }
        .frame(width: videoSize.width, height: videoSize.height)
    }

    /// The original centered layout, used when no transcript is included.
    private var classicContent: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: layout.contentTopPadding)

            Image(uiImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: layout.artworkSize, height: layout.artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: layout.artworkCornerRadius))

            Spacer()
                .frame(height: layout.titleSpacing)

            Text(episodeTitle)
                .font(.system(size: layout.titleFontSize, weight: .bold))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, layout.horizontalPadding)

            Spacer()
                .frame(height: layout.dateSpacing)

            Text(episodeDate, format: .dateTime.day().month(.wide).year())
                .font(.system(size: layout.dateFontSize))
                .foregroundStyle(textColor.opacity(0.6))

            Spacer(minLength: 0)
        }
        .frame(width: videoSize.width, height: layout.contentAreaHeight)
    }

    /// Transcript layout header: podcast logo for branding, with the episode
    /// title (up to two lines) and date beside it. The text block vertically
    /// centers against the logo so one- and two-line titles both sit well.
    private var headerRow: some View {
        let frame = layout.headerFrame
        return HStack(spacing: layout.headerTextGap) {
            Image("podcast_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: layout.headerLogoSize, height: layout.headerLogoSize)

            VStack(alignment: .leading, spacing: layout.headerTextSpacing) {
                Text(episodeTitle)
                    .font(.system(size: layout.headerTitleFontSize, weight: .bold))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text(episodeDate, format: .dateTime.day().month(.wide).year())
                    .font(.system(size: layout.headerDateFontSize))
                    .foregroundStyle(textColor.opacity(0.6))
            }

            Spacer(minLength: 0)
        }
        .frame(width: frame.width, height: frame.height, alignment: .leading)
        .offset(x: frame.origin.x, y: frame.origin.y)
    }

    // MARK: - Subviews

    /// Fills the frame with the square clip's designed background image,
    /// falling back to a solid color if the asset is ever missing.
    @ViewBuilder
    private var background: some View {
        if let backgroundImage = UIImage(named: "square_share_clip") {
            Image(uiImage: backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: videoSize.width, height: videoSize.height)
                .clipped()
        } else {
            backgroundColor
        }
    }

    /// Anchors viewers to where this clip sits in the full episode. The trailing
    /// countdown isn't rendered here — it's animated as a `CATextLayer` during
    /// video generation, the same way the progress fill is.
    private var leadingTimestampLabel: some View {
        let frame = layout.leadingTimestampFrame
        return Text(NowPlayingView.formatTime(clipStart))
            .font(.system(size: layout.timestampFontSize, weight: .semibold))
            .foregroundStyle(textColor.opacity(0.85))
            .monospacedDigit()
            .frame(width: frame.width, height: frame.height, alignment: .leading)
            .offset(x: frame.origin.x, y: frame.origin.y)
    }

    /// Mirrors the exported video's cue animation: the current cue crossfades
    /// in place, Apple Music lyrics style, as playback moves between cues.
    /// Rendered empty (slot reserved, no text) in the generator's static frame.
    @ViewBuilder
    private var transcriptSlot: some View {
        let frame = layout.transcriptFrame
        ZStack {
            if let transcriptText {
                Text(transcriptText)
                    .font(.system(size: layout.transcriptFontSize, weight: .semibold))
                    .foregroundStyle(textColor.opacity(0.95))
                    .multilineTextAlignment(.leading)
                    .lineLimit(layout.transcriptMaxLines)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(transcriptText)
                    .transition(.opacity)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .animation(.easeInOut(duration: 0.25), value: transcriptText)
        .offset(x: frame.origin.x, y: frame.origin.y)
    }

    private var trackBackground: some View {
        RoundedRectangle(cornerRadius: layout.trackCornerRadius)
            .fill(Color.black.opacity(0.1))
            .frame(width: layout.trackFrame.width, height: layout.trackFrame.height)
            .offset(
                x: layout.trackFrame.origin.x,
                y: layout.trackFrame.origin.y
            )
    }

    // MARK: - Colors

    private let backgroundColor = Color(red: 0.06, green: 0.24, blue: 0.14)
    private let textColor = Color.white
}

// MARK: - Preview

private let previewArtwork: UIImage = UIGraphicsImageRenderer(size: .init(width: 300, height: 300)).image { ctx in
    UIColor.systemOrange.setFill()
    ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
    UIColor.white.withAlphaComponent(0.25).setFill()
    ctx.fill(CGRect(x: 0, y: 120, width: 300, height: 60))
}

#Preview("Square") {
    ShareClipVideoFrameView(
        artwork: previewArtwork,
        episodeTitle: "O Fim do Mandato e as Perspectivas para 2026",
        episodeDate: .now,
        clipStart: 620,
        videoSize: .init(width: 1080, height: 1080)
    )
    .frame(width: 1080, height: 1080)
    .scaleEffect(0.35)
    .frame(width: 378, height: 378)
}

#Preview("Square – transcript") {
    ShareClipVideoFrameView(
        artwork: previewArtwork,
        episodeTitle: "O Fim do Mandato e as Perspectivas para 2026",
        episodeDate: .now,
        clipStart: 620,
        videoSize: .init(width: 1080, height: 1080),
        includesTranscript: true,
        transcriptText: "Aí o outro respondeu na mesma hora, no microfone aberto pra todo mundo ouvir, sem medo nenhum de dar ruim."
    )
    .frame(width: 1080, height: 1080)
    .scaleEffect(0.35)
    .frame(width: 378, height: 378)
}

#Preview("Square – long title") {
    ShareClipVideoFrameView(
        artwork: previewArtwork,
        episodeTitle: "Eleições 2026: Candidatos, Alianças e o Futuro da Democracia Brasileira",
        episodeDate: .now,
        clipStart: 3725,
        videoSize: .init(width: 1080, height: 1080)
    )
    .frame(width: 1080, height: 1080)
    .scaleEffect(0.35)
    .frame(width: 378, height: 378)
}
