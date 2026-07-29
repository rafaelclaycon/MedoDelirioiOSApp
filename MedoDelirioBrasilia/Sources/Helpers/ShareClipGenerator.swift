//
//  ShareClipGenerator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/02/26.
//

import AVFoundation
import SwiftUI
import UIKit

enum ShareClipGenerator {

    struct Configuration: Sendable {
        let episode: PodcastEpisode
        let audioFileURL: URL
        let clipStart: TimeInterval
        let clipEnd: TimeInterval
        /// Cues overlapping the selected clip range, in episode time.
        /// Empty when the episode has no transcript or the user opted out.
        var transcriptCues: [SRTCue] = []

        var includesTranscript: Bool { !transcriptCues.isEmpty }

        func removingTranscript() -> Configuration {
            var copy = self
            copy.transcriptCues = []
            return copy
        }
    }

    /// Fixed pixel dimensions for the exported clip. Portrait and landscape
    /// modes existed at one point but were never shipped — square is the only
    /// supported output for now.
    static let videoSize = CGSize(width: 1080, height: 1080)

    enum GenerationPhase: String, Sendable {
        case preparingAudio = "Preparando áudio…"
        case renderingFrame = "Renderizando quadro…"
        case writingVideo = "Gerando vídeo…"
        case composing = "Finalizando…"
    }

    /// Generates a shareable video clip and returns the URL to the final `.mp4`.
    static func generate(
        config: Configuration,
        onPhaseChange: (@Sendable (GenerationPhase) -> Void)? = nil
    ) async throws -> URL {
        let clipDuration = config.clipEnd - config.clipStart

        let artwork = await downloadArtwork(for: config.episode)

        onPhaseChange?(.preparingAudio)
        let trimmedAudioURL = try await trimAudio(
            from: config.audioFileURL,
            start: config.clipStart,
            end: config.clipEnd
        )

        onPhaseChange?(.renderingFrame)
        let frameImage = try await renderStaticFrame(
            episode: config.episode,
            artwork: artwork,
            clipStart: config.clipStart,
            videoSize: videoSize,
            includesTranscript: config.includesTranscript
        )

        onPhaseChange?(.writingVideo)
        let staticVideoURL = try await writeStaticVideo(
            from: frameImage,
            duration: clipDuration,
            size: videoSize
        )

        onPhaseChange?(.composing)
        let finalURL = try await composeFinalVideo(
            staticVideoURL: staticVideoURL,
            trimmedAudioURL: trimmedAudioURL,
            videoSize: videoSize,
            clipDuration: clipDuration,
            config: config
        )

        cleanup(urls: [trimmedAudioURL, staticVideoURL])
        return finalURL
    }

    /// Removes all previously generated ShareClip clip files.
    static func cleanupOutputDirectory() {
        removeIfExists(at: outputDirectory)
    }

    // MARK: - Step 1: Download Artwork

    /// Falls back to `placeholderArtwork` on any failure instead of throwing,
    /// so a broken/missing artwork URL doesn't fail the whole export after
    /// the confirm screen already showed the same placeholder as if nothing
    /// were wrong.
    private static func downloadArtwork(for episode: PodcastEpisode) async -> UIImage {
        guard let imageURL = episode.imageURL,
              let (data, _) = try? await URLSession.shared.data(from: imageURL),
              let image = UIImage(data: data)
        else {
            return placeholderArtwork
        }
        return image
    }

    /// Shared with `ShareClipConfirmView`, which shows the same fallback
    /// while the real artwork is still downloading.
    static let placeholderArtwork: UIImage = UIGraphicsImageRenderer(
        size: .init(width: 100, height: 100)
    ).image { ctx in
        UIColor.gray.withAlphaComponent(0.2).setFill()
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    // MARK: - Step 2: Trim Audio

    private static func trimAudio(
        from sourceURL: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("shareclip_trim_\(UUID().uuidString).m4a")

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw ShareClipError.audioTrimFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        await session.export()

        guard session.status == .completed else {
            throw ShareClipError.audioTrimFailed
        }
        return outputURL
    }

    // MARK: - Step 3: Render Static Frame

    @MainActor
    private static func renderStaticFrame(
        episode: PodcastEpisode,
        artwork: UIImage,
        clipStart: TimeInterval,
        videoSize: CGSize,
        includesTranscript: Bool
    ) throws -> UIImage {
        // Transcript text is deliberately left out of the static frame
        // (`transcriptText: nil`): the cues are composited as animated
        // `CALayer` bitmaps on top of the reserved, empty slot.
        let view = ShareClipVideoFrameView(
            artwork: artwork,
            episodeTitle: episode.title,
            episodeDate: episode.pubDate,
            clipStart: clipStart,
            videoSize: videoSize,
            includesTranscript: includesTranscript
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else {
            throw ShareClipError.frameRenderFailed
        }
        return image
    }

    // MARK: - Step 4: Write Static Video

    private static func writeStaticVideo(
        from image: UIImage,
        duration: TimeInterval,
        size: CGSize
    ) async throws -> URL {
        guard let ciImage = CIImage(image: image) else {
            throw ShareClipError.frameRenderFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("shareclip_static_\(UUID().uuidString).mov")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        // Source attributes must declare IOSurface-backed BGRA — otherwise VideoToolbox rejects the frames during downstream export with err=-12900.
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        guard let pool = adaptor.pixelBufferPool else {
            throw ShareClipError.videoWriteFailed
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else {
            throw ShareClipError.frameRenderFailed
        }
        CIContext().render(ciImage, to: buffer)

        let fps: Int32 = 30
        let totalFrames = Int(ceil(duration * Double(fps)))

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            nonisolated(unsafe) var frameCount = 0
            nonisolated(unsafe) var hasResumed = false
            let queue = DispatchQueue(label: "com.medoedelirio.shareclip.videowriter")

            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard !hasResumed else { return }
                    guard writer.status == .writing else {
                        hasResumed = true
                        continuation.resume(throwing: ShareClipError.videoWriteFailed)
                        return
                    }
                    guard frameCount < totalFrames else {
                        input.markAsFinished()
                        hasResumed = true
                        continuation.resume()
                        return
                    }
                    let time = CMTimeMake(value: Int64(frameCount), timescale: fps)
                    adaptor.append(buffer, withPresentationTime: time)
                    frameCount += 1
                }
            }
        }

        await writer.finishWriting()

        guard writer.status == .completed else {
            throw ShareClipError.videoWriteFailed
        }
        return outputURL
    }

    // MARK: - Step 5: Compose Final Video

    private static func composeFinalVideo(
        staticVideoURL: URL,
        trimmedAudioURL: URL,
        videoSize: CGSize,
        clipDuration: TimeInterval,
        config: Configuration
    ) async throws -> URL {
        let composition = AVMutableComposition()

        let videoAsset = AVAsset(url: staticVideoURL)
        let audioAsset = AVAsset(url: trimmedAudioURL)

        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        guard
            let compVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let srcVideoTrack = videoTracks.first,
            let compAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ),
            let srcAudioTrack = audioTracks.first
        else {
            throw ShareClipError.compositionFailed
        }

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        let safeDuration = CMTimeMinimum(videoDuration, audioDuration)

        // Both tracks must equal safeDuration so the composition's duration matches the instruction's timeRange — otherwise export aborts as interrupted.
        try compVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: safeDuration),
            of: srcVideoTrack,
            at: .zero
        )
        try compAudioTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: safeDuration),
            of: srcAudioTrack,
            at: .zero
        )

        // Layer tree must be built on main — AVVideoCompositionCoreAnimationTool aborts via XPC misuse if its layers were created off-main.
        let videoComposition = await MainActor.run { () -> AVMutableVideoComposition in
            buildVideoComposition(
                videoSize: videoSize,
                safeDuration: safeDuration,
                compVideoTrack: compVideoTrack,
                config: config
            )
        }

        // -- Export --
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let outputURL = outputDirectory.appendingPathComponent(exportFileName(for: config))
        removeIfExists(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ShareClipError.exportFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        await session.export()

        guard session.status == .completed else {
            if let error = session.error { throw error }
            throw ShareClipError.exportFailed
        }
        return outputURL
    }

    @MainActor
    private static func buildVideoComposition(
        videoSize: CGSize,
        safeDuration: CMTime,
        compVideoTrack: AVMutableCompositionTrack,
        config: Configuration
    ) -> AVMutableVideoComposition {
        let layout = ShareClipVideoLayout(
            videoSize: videoSize,
            includesTranscript: config.includesTranscript
        )
        let track = layout.trackFrame

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)

        let videoLayer = CALayer()
        videoLayer.frame = parentLayer.frame
        parentLayer.addSublayer(videoLayer)

        // Core Animation uses bottom-left origin; convert track Y.
        let trackY_CA = videoSize.height - track.origin.y - track.height

        let fillLayer = CALayer()
        fillLayer.backgroundColor = UIColor.systemOrange.cgColor
        fillLayer.cornerRadius = layout.trackCornerRadius
        fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        fillLayer.position = CGPoint(x: track.origin.x, y: trackY_CA + track.height / 2)
        fillLayer.bounds = CGRect(x: 0, y: 0, width: 0, height: track.height)

        let anim = CABasicAnimation(keyPath: "bounds.size.width")
        anim.fromValue = 0
        anim.toValue = track.width
        anim.beginTime = AVCoreAnimationBeginTimeAtZero
        anim.duration = CMTimeGetSeconds(safeDuration)
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards
        fillLayer.add(anim, forKey: "progressFill")

        parentLayer.addSublayer(fillLayer)
        parentLayer.addSublayer(countdownLayer(layout: layout, videoSize: videoSize, safeDuration: safeDuration))

        for layer in transcriptCueLayers(
            config: config,
            layout: layout,
            videoSize: videoSize,
            safeDuration: safeDuration
        ) {
            parentLayer.addSublayer(layer)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: safeDuration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        return videoComposition
    }

    /// Builds the trailing "time remaining" label as a plain `CALayer` whose
    /// `contents` is keyframed through one pre-rendered bitmap per second.
    ///
    /// A `CATextLayer` with an animated `string` looks right in Xcode previews
    /// but renders frozen once passed through `AVVideoCompositionCoreAnimationTool`:
    /// its custom text-drawing path reads the layer's live model value directly
    /// instead of the interpolated/keyframed one, so the export just bakes in
    /// whatever `string` happened to be at snapshot time. `contents`, on the
    /// other hand, is a genuine compositor-level property — the same kind the
    /// progress fill's `bounds` animation relies on — so keyframing it through
    /// a sequence of images actually gets resampled per frame.
    @MainActor
    private static func countdownLayer(
        layout: ShareClipVideoLayout,
        videoSize: CGSize,
        safeDuration: CMTime
    ) -> CALayer {
        let frame = layout.trailingTimestampFrame
        let frameCA = CGRect(
            x: frame.origin.x,
            y: videoSize.height - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )

        let durationSeconds = CMTimeGetSeconds(safeDuration)
        let totalSeconds = max(Int(durationSeconds.rounded(.up)), 1)
        // One extra step beyond `totalSeconds` so the final value is 0
        // ("-0:00"), with every step — including that last one — getting an
        // equal, fully visible slice of the clip. Real clip durations almost
        // always have a fractional remainder (e.g. 24.3s), so keying steps to
        // exact one-second boundaries left the final step compressed into
        // just that leftover fraction — often too short to actually be seen,
        // which is why the countdown appeared to freeze a couple seconds early.
        let stepCount = totalSeconds + 1

        let scale: CGFloat = 3
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: frame.size, format: format)

        let font = UIFont.systemFont(ofSize: layout.timestampFontSize, weight: .semibold)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            .paragraphStyle: paragraphStyle
        ]

        let images: [CGImage] = (0..<stepCount).map { i in
            let remaining = totalSeconds - i
            let text = ("-" + NowPlayingView.formatTime(TimeInterval(remaining))) as NSString
            let image = renderer.image { _ in
                let y = (frame.height - font.lineHeight) / 2
                text.draw(
                    in: CGRect(x: 0, y: y, width: frame.width, height: font.lineHeight),
                    withAttributes: attributes
                )
            }
            return image.cgImage!
        }

        let layer = CALayer()
        layer.frame = frameCA
        layer.contentsScale = scale
        layer.contents = images.first

        let keyTimes = (0..<stepCount).map { NSNumber(value: Double($0) / Double(stepCount)) }

        let countdown = CAKeyframeAnimation(keyPath: "contents")
        countdown.values = images
        countdown.keyTimes = keyTimes
        countdown.calculationMode = .discrete
        countdown.beginTime = AVCoreAnimationBeginTimeAtZero
        countdown.duration = durationSeconds
        countdown.isRemovedOnCompletion = false
        countdown.fillMode = .forwards
        layer.add(countdown, forKey: "countdown")

        return layer
    }

    // MARK: - Transcript Layers

    /// Builds one `CALayer` per transcript cue, each holding a pre-rendered
    /// bitmap of the cue's text, faded in/out at the cue's boundaries and given
    /// a subtle upward drift on entry — echoing the lyrics-style transition the
    /// app uses in Now Playing.
    ///
    /// Bitmaps + compositor-level properties (`opacity`, `position`) are used
    /// for the same reason as the countdown: a `CATextLayer` with an animated
    /// `string` renders frozen through `AVVideoCompositionCoreAnimationTool`.
    @MainActor
    private static func transcriptCueLayers(
        config: Configuration,
        layout: ShareClipVideoLayout,
        videoSize: CGSize,
        safeDuration: CMTime
    ) -> [CALayer] {
        guard config.includesTranscript else { return [] }
        let duration = CMTimeGetSeconds(safeDuration)
        guard duration > 0 else { return [] }

        let frame = layout.transcriptFrame
        // Core Animation uses bottom-left origin; convert the slot's Y.
        let frameCA = CGRect(
            x: frame.origin.x,
            y: videoSize.height - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        let fade: TimeInterval = 0.25
        let rise: CGFloat = 14

        return config.transcriptCues.compactMap { cue in
            let start = min(max(cue.startTime - config.clipStart, 0), duration)
            let end = min(max(cue.endTime - config.clipStart, 0), duration)
            guard end - start > 0.1 else { return nil }
            guard let image = transcriptCueImage(text: cue.text, layout: layout) else { return nil }

            let layer = CALayer()
            layer.frame = frameCA
            layer.contentsScale = transcriptRenderScale
            layer.contents = image
            layer.opacity = 0

            // Keyframes are normalized over the whole clip so a single
            // animation per layer covers hidden → fade in → hold → fade out.
            let fadeInEnd = min(start + fade, end)
            let fadeOutStart = max(end - fade, fadeInEnd)

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0, 0, 1, 1, 0, 0] as [Float]
            opacity.keyTimes = [0, start / duration, fadeInEnd / duration, fadeOutStart / duration, end / duration, 1]
                .map { NSNumber(value: $0) }
            opacity.beginTime = AVCoreAnimationBeginTimeAtZero
            opacity.duration = duration
            opacity.isRemovedOnCompletion = false
            opacity.fillMode = .forwards
            layer.add(opacity, forKey: "cueOpacity")

            // In CA's bottom-left space a smaller Y is lower on screen, so
            // starting below the resting position and animating up reads as
            // the incoming line drifting into place.
            let restingY = frameCA.midY
            let drift = CAKeyframeAnimation(keyPath: "position.y")
            drift.values = [restingY - rise, restingY - rise, restingY, restingY]
            drift.keyTimes = [0, start / duration, fadeInEnd / duration, 1]
                .map { NSNumber(value: $0) }
            drift.beginTime = AVCoreAnimationBeginTimeAtZero
            drift.duration = duration
            drift.isRemovedOnCompletion = false
            drift.fillMode = .forwards
            layer.add(drift, forKey: "cueDrift")

            return layer
        }
    }

    private static let transcriptRenderScale: CGFloat = 2

    /// Renders one cue's text into a bitmap sized to the transcript slot,
    /// left-aligned and vertically centered, shrinking the font (mirroring
    /// the preview's `minimumScaleFactor(0.7)`) when a long cue would overflow.
    private static func transcriptCueImage(
        text: String,
        layout: ShareClipVideoLayout
    ) -> CGImage? {
        let size = layout.transcriptFrame.size
        guard size.width > 0, size.height > 0 else { return nil }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let baseFontSize = layout.transcriptFontSize
        var font = UIFont.systemFont(ofSize: baseFontSize, weight: .semibold)
        var textHeight = size.height
        for factor in [1.0, 0.85, 0.7] {
            font = UIFont.systemFont(ofSize: baseFontSize * factor, weight: .semibold)
            let bounding = (text as NSString).boundingRect(
                with: CGSize(width: size.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraphStyle],
                context: nil
            )
            textHeight = ceil(bounding.height)
            if textHeight <= size.height { break }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(0.95),
            .paragraphStyle: paragraphStyle
        ]

        let format = UIGraphicsImageRendererFormat()
        format.scale = transcriptRenderScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        let y = max((size.height - textHeight) / 2, 0)
        let image = renderer.image { _ in
            (text as NSString).draw(
                in: CGRect(x: 0, y: y, width: size.width, height: min(textHeight, size.height)),
                withAttributes: attributes
            )
        }
        return image.cgImage
    }

    // MARK: - Helpers

    private static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ShareClips")
    }

    private static func removeIfExists(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func cleanup(urls: [URL]) {
        for url in urls { removeIfExists(at: url) }
    }

    /// A user-facing filename derived from the episode title and clip start
    /// time, so the exported file (visible in Files, AirDrop, Mail, etc.)
    /// reads as the actual clip rather than a generic, identical-every-time name.
    private static func exportFileName(for config: Configuration) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitizedTitle = config.episode.title
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let maxTitleLength = 60
        let title = sanitizedTitle.isEmpty ? "Clipe" : String(sanitizedTitle.prefix(maxTitleLength))

        let clipStartTag = NowPlayingView.formatTime(config.clipStart).replacingOccurrences(of: ":", with: "-")

        return "\(title) - \(clipStartTag).mp4"
    }
}

// MARK: - Errors

enum ShareClipError: Error, LocalizedError {

    case audioTrimFailed
    case frameRenderFailed
    case videoWriteFailed
    case compositionFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .audioTrimFailed: "Falha ao recortar o áudio."
        case .frameRenderFailed: "Falha ao renderizar o quadro do vídeo."
        case .videoWriteFailed: "Falha ao gravar o vídeo."
        case .compositionFailed: "Falha ao montar a composição do vídeo."
        case .exportFailed: "Falha ao exportar o clipe final."
        }
    }
}
