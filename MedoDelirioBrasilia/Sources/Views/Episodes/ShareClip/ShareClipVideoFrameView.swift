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

    private var isPortrait: Bool { videoSize.height > videoSize.width }
    private var isLandscape: Bool { videoSize.width > videoSize.height }

    var horizontalPadding: CGFloat { videoSize.width * 0.1 }

    var artworkSize: CGFloat {
        if isPortrait { return videoSize.width * 0.55 }
        if isLandscape { return min(videoSize.height * 0.45, videoSize.width * 0.28) }
        return videoSize.width * 0.50
    }

    var artworkCornerRadius: CGFloat { artworkSize * 0.06 }

    var artworkTopPadding: CGFloat {
        if isPortrait { return videoSize.height * 0.15 }
        if isLandscape { return videoSize.height * 0.08 }
        return videoSize.height * 0.08
    }

    var titleSpacing: CGFloat { videoSize.height * 0.035 }
    var dateSpacing: CGFloat { videoSize.height * 0.015 }

    var titleFontSize: CGFloat {
        if isLandscape { return 44 }
        return 40
    }

    var dateFontSize: CGFloat { titleFontSize * 0.7 }
    var brandingFontSize: CGFloat { titleFontSize * 0.6 }

    var trackCornerRadius: CGFloat { trackFrame.height / 2 }

    /// The progress bar track rectangle in the video's coordinate system.
    var trackFrame: CGRect {
        let padding = horizontalPadding
        let height: CGFloat = max(videoSize.height * 0.005, 6)
        let width = videoSize.width - 2 * padding
        let y: CGFloat
        if isPortrait { y = videoSize.height * 0.65 }
        else if isLandscape { y = videoSize.height * 0.78 }
        else { y = videoSize.height * 0.82 }
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

    var brandingY: CGFloat {
        if isPortrait { return videoSize.height * 0.72 }
        if isLandscape { return videoSize.height * 0.88 }
        return videoSize.height * 0.90
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

    private var layout: ShareClipVideoLayout { .init(videoSize: videoSize) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: layout.artworkTopPadding)

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

                Spacer()
            }
            .frame(width: videoSize.width)

            trackBackground

            leadingTimestampLabel

            brandingLabel
        }
        .frame(width: videoSize.width, height: videoSize.height)
    }

    // MARK: - Subviews

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

    private var trackBackground: some View {
        RoundedRectangle(cornerRadius: layout.trackCornerRadius)
            .fill(Color.black.opacity(0.1))
            .frame(width: layout.trackFrame.width, height: layout.trackFrame.height)
            .offset(
                x: layout.trackFrame.origin.x,
                y: layout.trackFrame.origin.y
            )
    }

    private var brandingLabel: some View {
        Text("Clipe criado com Medo e Delírio iOS")
            .font(.system(size: layout.brandingFontSize, weight: .medium))
            .foregroundStyle(textColor.opacity(0.4))
            .frame(width: videoSize.width)
            .offset(y: layout.brandingY)
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
