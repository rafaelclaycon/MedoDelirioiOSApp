//
//  SidecastClipGenerator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 25/02/26.
//

import AVFoundation
import SwiftUI
import UIKit

enum SidecastClipGenerator {

    struct Configuration: Sendable {
        let episode: PodcastEpisode
        let audioFileURL: URL
        let clipStart: TimeInterval
        let clipEnd: TimeInterval
        let shareMode: SidecastClipShareMode
    }

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
        guard let videoSize = config.shareMode.videoSize else {
            throw SidecastClipError.unsupportedMode
        }
        let clipDuration = config.clipEnd - config.clipStart

        let artwork = try await downloadArtwork(for: config.episode)

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
            videoSize: videoSize
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
            clipDuration: clipDuration
        )

        cleanup(urls: [trimmedAudioURL, staticVideoURL])
        return finalURL
    }

    /// Removes all previously generated Sidecast clip files.
    static func cleanupOutputDirectory() {
        removeIfExists(at: outputDirectory)
    }

    // MARK: - Step 1: Download Artwork

    private static func downloadArtwork(for episode: PodcastEpisode) async throws -> UIImage {
        guard let imageURL = episode.imageURL else {
            throw SidecastClipError.missingArtwork
        }
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        guard let image = UIImage(data: data) else {
            throw SidecastClipError.invalidArtwork
        }
        return image
    }

    // MARK: - Step 2: Trim Audio

    private static func trimAudio(
        from sourceURL: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> URL {
        let asset = AVAsset(url: sourceURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidecast_trim_\(UUID().uuidString).m4a")

        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw SidecastClipError.audioTrimFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        await session.export()

        guard session.status == .completed else {
            throw SidecastClipError.audioTrimFailed
        }
        return outputURL
    }

    // MARK: - Step 3: Render Static Frame

    @MainActor
    private static func renderStaticFrame(
        episode: PodcastEpisode,
        artwork: UIImage,
        videoSize: CGSize
    ) throws -> UIImage {
        let view = SidecastVideoFrameView(
            artwork: artwork,
            episodeTitle: episode.title,
            episodeDate: episode.pubDate,
            videoSize: videoSize
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        guard let image = renderer.uiImage else {
            throw SidecastClipError.frameRenderFailed
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
            throw SidecastClipError.frameRenderFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sidecast_static_\(UUID().uuidString).mov")

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
            throw SidecastClipError.videoWriteFailed
        }
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else {
            throw SidecastClipError.frameRenderFailed
        }
        CIContext().render(ciImage, to: buffer)

        let fps: Int32 = 30
        let totalFrames = Int(ceil(duration * Double(fps)))

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            nonisolated(unsafe) var frameCount = 0
            nonisolated(unsafe) var hasResumed = false
            let queue = DispatchQueue(label: "com.medoedelirio.sidecast.videowriter")

            input.requestMediaDataWhenReady(on: queue) {
                while input.isReadyForMoreMediaData {
                    guard !hasResumed else { return }
                    guard writer.status == .writing else {
                        hasResumed = true
                        continuation.resume(throwing: SidecastClipError.videoWriteFailed)
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
            throw SidecastClipError.videoWriteFailed
        }
        return outputURL
    }

    // MARK: - Step 5: Compose Final Video

    private static func composeFinalVideo(
        staticVideoURL: URL,
        trimmedAudioURL: URL,
        videoSize: CGSize,
        clipDuration: TimeInterval
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
            throw SidecastClipError.compositionFailed
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
                compVideoTrack: compVideoTrack
            )
        }

        // -- Export --
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let outputURL = outputDirectory.appendingPathComponent("sidecast_clip.mp4")
        removeIfExists(at: outputURL)

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw SidecastClipError.exportFailed
        }

        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.videoComposition = videoComposition
        session.shouldOptimizeForNetworkUse = true

        await session.export()

        guard session.status == .completed else {
            if let error = session.error { throw error }
            throw SidecastClipError.exportFailed
        }
        return outputURL
    }

    @MainActor
    private static func buildVideoComposition(
        videoSize: CGSize,
        safeDuration: CMTime,
        compVideoTrack: AVMutableCompositionTrack
    ) -> AVMutableVideoComposition {
        let layout = SidecastVideoLayout(videoSize: videoSize)
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

    // MARK: - Helpers

    private static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SidecastClips")
    }

    private static func removeIfExists(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func cleanup(urls: [URL]) {
        for url in urls { removeIfExists(at: url) }
    }
}

// MARK: - Errors

enum SidecastClipError: Error, LocalizedError {

    case unsupportedMode
    case missingArtwork
    case invalidArtwork
    case audioTrimFailed
    case frameRenderFailed
    case videoWriteFailed
    case compositionFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedMode: "O modo selecionado não suporta exportação de vídeo."
        case .missingArtwork: "Imagem do episódio não encontrada."
        case .invalidArtwork: "Não foi possível carregar a imagem do episódio."
        case .audioTrimFailed: "Falha ao recortar o áudio."
        case .frameRenderFailed: "Falha ao renderizar o quadro do vídeo."
        case .videoWriteFailed: "Falha ao gravar o vídeo."
        case .compositionFailed: "Falha ao montar a composição do vídeo."
        case .exportFailed: "Falha ao exportar o clipe final."
        }
    }
}
