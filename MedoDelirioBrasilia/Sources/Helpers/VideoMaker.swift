import UIKit
import AVFoundation

class VideoMaker {

    /// The shortest a generated video can be, in seconds. Sounds shorter than this
    /// are padded with a frozen frame so they don't loop frantically on platforms
    /// like X and so viewers have time to read the content in an Instagram Story.
    static let minimumDuration: CGFloat = 5.0

    /// A little breathing room added to the end of every video so the last frame
    /// doesn't cut the instant the sound finishes — even for sounds already longer
    /// than `minimumDuration`.
    static let endTail: CGFloat = 0.5

    static func createVideo(
        from content: any MedoContentProtocol,
        with sourceImage: UIImage,
        exportType: IntendedVideoDestination
    ) async throws -> String? {
        let contentUrl = try content.fileURL()

        guard let audioDuration = VideoMaker.getAudioFileDuration(fileURL: contentUrl) else {
            throw VideoMakerError.couldNotObtainAudioDuration
        }

        let videoDuration = max(audioDuration, minimumDuration) + endTail

        return try await VideoMaker.createVideo(
            fromImage: sourceImage,
            withDuration: videoDuration,
            andName: content.title,
            contentUrl: contentUrl,
            exportType: exportType
        )
    }

    static func getAudioFileDuration(fileURL: URL) -> CGFloat? {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            return CGFloat(audioPlayer.duration)
        } catch {
            assertionFailure("Failed creating audio player: \(error).")
            return nil
        }
    }
    
    static func merge(
        audio audioUrl: URL,
        and videoUrl: URL,
        videoName: String,
        exportType: IntendedVideoDestination
    ) async throws -> URL? {
        let mixComposition: AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack: [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack: [AVMutableCompositionTrack] = []
        let totalVideoCompositionInstruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()

        let aVideoAsset: AVAsset = AVAsset(url: videoUrl)
        let aAudioAsset: AVAsset = AVAsset(url: audioUrl)

        if
            let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        {
            mutableCompositionVideoTrack.append(videoTrack)
            mutableCompositionAudioTrack.append(audioTrack)

            if
                let aVideoAssetTrack: AVAssetTrack = aVideoAsset.tracks(withMediaType: .video).first,
                let aAudioAssetTrack: AVAssetTrack = aAudioAsset.tracks(withMediaType: .audio).first
            {
                do {
                    try mutableCompositionVideoTrack.first?.insertTimeRange(
                        CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration),
                        of: aVideoAssetTrack,
                        at: CMTime.zero
                    )

                    // Play the sound exactly once at the start, then hold on the frozen
                    // frame in silence for the rest of the (padded) video. We never loop
                    // the audio — looping would just recreate the frantic repetition that
                    // padding the video is meant to avoid.
                    let audioDuration = CMTimeMinimum(
                        aAudioAssetTrack.timeRange.duration,
                        aVideoAssetTrack.timeRange.duration
                    )
                    try mutableCompositionAudioTrack.first?.insertTimeRange(
                        CMTimeRangeMake(start: CMTime.zero, duration: audioDuration),
                        of: aAudioAssetTrack,
                        at: CMTime.zero
                    )

                    videoTrack.preferredTransform = aVideoAssetTrack.preferredTransform
                } catch {
                    print(error)
                }
                
                totalVideoCompositionInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: aVideoAssetTrack.timeRange.duration)
            }
        }

        let mutableVideoComposition: AVMutableVideoComposition = AVMutableVideoComposition()
        mutableVideoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)

        var videoWidth: Int = 0
        var videoHeight: Int = 0

        if exportType == IntendedVideoDestination.twitter {
            videoWidth = 1000
            videoHeight = 1000
        } else {
            videoWidth = 1080
            videoHeight = 1920
        }

        mutableVideoComposition.renderSize = CGSize(width: videoWidth, height: videoHeight)

        guard
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        else { return nil }
        let outputURL = URL(fileURLWithPath: documentsPath).appendingPathComponent("\(videoName).mov")

        do {
            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }
        } catch {
            print("Could not remove file: \(error.localizedDescription)")
        }

        guard
            let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        else { return nil }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = true

        // try to export the file and handle the status cases
        await exportSession.export()

        return outputURL
    }

    /// Creates the video in the app's Documents folder and returns the path to the file.
    static func createVideo(
        fromImage image: UIImage,
        withDuration duration: CGFloat,
        andName videoName: String,
        contentUrl: URL,
        exportType: IntendedVideoDestination
    ) async throws -> String? {
        guard let staticImage = CIImage(image: image) else {
            throw VideoMakerError.invalidImage
        }
        
        var pixelBuffer: CVPixelBuffer?
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let width: Int = Int(staticImage.extent.size.width)
        let height: Int = Int(staticImage.extent.size.height)
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        let context = CIContext()
        
        context.render(staticImage, to: pixelBuffer!)
        
        guard
            let imageNameRoot = videoName.split(separator: ".").first,
            let outputMovieURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask).first?.appendingPathComponent("\(imageNameRoot).mov"
            )
        else {
            throw VideoMakerError.invalidURL
        }
        
        // Delete any old file
        do {
            try FileManager.default.removeItem(at: outputMovieURL)
        } catch {
            print("Could not remove file: \(error.localizedDescription)")
        }
        
        guard let assetwriter = try? AVAssetWriter(outputURL: outputMovieURL, fileType: .mov) else {
            abort()
        }
        
        var videoWidth: Int = 0
        var videoHeight: Int = 0
        
        if exportType == IntendedVideoDestination.twitter {
            videoWidth = 1000
            videoHeight = 1000
        } else {
            videoWidth = 1080
            videoHeight = 1920
        }
        
        let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: videoWidth, AVVideoHeightKey: videoHeight] as [String: Any]
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: assetWriterSettings)
        let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
        
        assetwriter.add(assetWriterInput)
        
        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: CMTime.zero)
        
        let framesPerSecond = 30.0
        
        let totalFrames = duration * framesPerSecond
        var frameCount = 0.0
        while frameCount < totalFrames {
            if assetWriterInput.isReadyForMoreMediaData {
                let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
                assetWriterAdaptor.append(pixelBuffer!, withPresentationTime: frameTime)
                frameCount+=1
            }
        }

        assetWriterInput.markAsFinished()
        await assetwriter.finishWriting()

        pixelBuffer = nil

        guard
            let videoUrl = try await merge(
                audio: contentUrl,
                and: outputMovieURL,
                videoName: videoName,
                exportType: exportType
            )
        else { return nil }
        return videoUrl.path
    }
}

enum VideoMakerError: Error, LocalizedError {

    case invalidImage
    case invalidURL
    case soundFilepathIsEmpty
    case unableToFindSoundFile
    case failedToMergeSoundAndVideo
    case couldNotObtainAudioDuration
    case unableToFindVideoFile
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "A imagem passada para a criação do vídeo é inválida."
        case .invalidURL:
            return "A URL criada para localizar o vídeo gerado é inválida."
        case .soundFilepathIsEmpty:
            return "O caminho do arquivo de som está vazio."
        case .unableToFindSoundFile:
            return "Não foi possível encontrar o arquivo do som."
        case .failedToMergeSoundAndVideo:
            return "Falha ao tentar unir o som ao vídeo."
        case .couldNotObtainAudioDuration:
            return "Não foi possível obter a duração do som."
        case .unableToFindVideoFile:
            return "Não foi possível localizar o arquivo do vídeo gerado."
        case .unknownError:
            return "Erro desconhecido."
        }
    }
}
