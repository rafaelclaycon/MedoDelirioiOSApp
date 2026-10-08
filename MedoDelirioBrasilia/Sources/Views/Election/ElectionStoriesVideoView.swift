//
//  ElectionStoriesVideoView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/10/26.
//

import AVFoundation
import CoreImage
import PhotosUI
import SwiftUI

/// Dev Options tool: a 9:16 video for the app's Instagram Stories that looks like a Lock
/// Screen on election night, with the real Live Activity view (`ElectionLockScreenView`)
/// updating as the count goes. The numbers are made up, so a "SIMULAÇÃO" seal sits on the
/// activity: real candidates with invented shares could pass for a poll or a result if the
/// picture gets around without context. Not for users.
struct ElectionStoriesVideoView: View {

    @State private var startedAt = Date.now
    @State private var laps = 1
    /// Picked from the photo library each time, so the app doesn't ship a wallpaper.
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var wallpaper: UIImage?
    @State private var exportProgress: Double?
    @State private var videoURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: .spacing(.large)) {
            TimelineView(.animation(paused: exportProgress != nil)) { context in
                GeometryReader { proxy in
                    let size = ElectionStoriesFrame.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    ElectionStoriesFrame(time: context.date.timeIntervalSince(startedAt), wallpaper: wallpaper)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: size.width * scale, height: size.height * scale, alignment: .topLeading)
                        .clipShape(.rect(cornerRadius: 12))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            PhotosPicker(selection: $wallpaperItem, matching: .images) {
                Label(wallpaper == nil ? "Escolher Papel de Parede" : "Trocar Papel de Parede", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(exportProgress != nil)

            Picker("Duração", selection: $laps) {
                Text("1 volta (\(Int(ElectionStoriesTimeline.loopDuration)) s)").tag(1)
                Text("2 voltas (\(Int(ElectionStoriesTimeline.loopDuration * 2)) s)").tag(2)
            }
            .pickerStyle(.segmented)
            .disabled(exportProgress != nil)

            if let exportProgress {
                ProgressView(value: exportProgress) {
                    Text("Gerando vídeo… \(Int(exportProgress * 100))%")
                        .font(.footnote)
                }
            } else {
                Button {
                    Task { await export() }
                } label: {
                    Label("Exportar Vídeo 1080 × 1920", systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Vídeo para Stories")
        .navigationBarTitleDisplayMode(.inline)
        .shareSheet(item: $videoURL, activityItems: { [$0] })
        .task(id: wallpaperItem) {
            guard let wallpaperItem else { return }
            if let data = try? await wallpaperItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                wallpaper = image
            } else {
                errorMessage = "Não foi possível abrir essa imagem."
            }
        }
        .alert("Erro ao Exportar", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func export() async {
        exportProgress = 0
        defer { exportProgress = nil }
        do {
            videoURL = try await ElectionStoriesVideoExporter.export(laps: laps, wallpaper: wallpaper) { progress in
                exportProgress = progress
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Frame

/// One frame of the video at `time` seconds: a Lock Screen with the Live Activity. Everything
/// that changes comes from `ElectionStoriesTimeline`, so any frame can be rendered on its own.
struct ElectionStoriesFrame: View {

    let time: TimeInterval
    /// The Lock Screen wallpaper, picked from the photo library. A dark gradient without one.
    var wallpaper: UIImage?

    /// An iPhone's width in points, at 9:16. Exported at 1080 × 1920, so the Live Activity
    /// shows life-size on a phone, with the room a real one has.
    static let size = CGSize(width: 393, height: 393 * 16 / 9)
    static let exportSize = CGSize(width: 1080, height: 1920)

    private static let activityMargin: CGFloat = 30
    private static let cardCornerRadius: CGFloat = 24

    var body: some View {
        let frame = ElectionStoriesTimeline.frame(at: time)

        ZStack {
            wallpaperBackground

            VStack(spacing: 0) {
                // No Dynamic Island, flashlight or home indicator: the phone playing the
                // Story has its own, and Instagram covers those spots anyway. Its progress
                // bar and profile take roughly the top 80 pt.
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.top, 86)

                Text(frame.date)
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 8)

                Text(frame.clock)
                    .font(.system(size: 92, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .tracking(-2)
                    .padding(.top, -6)

                Spacer()

                // Where the eye lands in a Story, clear of Instagram's reply bar.
                VStack(spacing: 8) {
                    // In front, so the beacon's rings pass behind it.
                    notification(frame)
                        .zIndex(1)
                    activity(frame)
                }
                .padding(.horizontal, Self.activityMargin)
                .padding(.bottom, 150)
            }
            .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    /// The push that goes out when the count starts, as iOS stacks it above the activity.
    /// The glass is drawn by hand: blur materials don't come out of `ImageRenderer`.
    private func notification(_ frame: ElectionStoriesTimeline.Frame) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image("IconePadrao")
                .resizable()
                .frame(width: 38, height: 38)
                .clipShape(.rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("A apuração começou!")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(frame.notificationAge)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("Acompanhe na Tela Bloqueada, com dados oficiais do TSE.")
                    .font(.system(size: 15))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                .fill(.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                )
        }
    }

    /// The real Live Activity view. When the leader changes, the old and the new order
    /// cross-fade, as iOS does between two updates. Rings keep pulsing out of it like a
    /// beacon, on a steady beat of their own, to draw the eye to it.
    private func activity(_ frame: ElectionStoriesTimeline.Frame) -> some View {
        ZStack {
            ElectionLockScreenView(round: 1, state: frame.state, isStale: false)
            if let incoming = frame.incomingState {
                ElectionLockScreenView(round: 1, state: incoming, isStale: false)
                    .opacity(frame.incomingOpacity)
            }
        }
        .clipShape(.rect(cornerRadius: Self.cardCornerRadius, style: .continuous))
        .background {
            // Two rings half a beat apart, each growing out of the edge and fading.
            ForEach(0..<2, id: \.self) { ring in
                let phase = (frame.beacon + Double(ring) / 2).truncatingRemainder(dividingBy: 1)
                let grow = 20 * (1 - pow(1 - phase, 3))
                RoundedRectangle(cornerRadius: Self.cardCornerRadius + grow, style: .continuous)
                    .stroke(ElectionPalette.bar.opacity(0.9 * (1 - phase)), lineWidth: 1 + 2 * (1 - phase))
                    .padding(-grow)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                .strokeBorder(ElectionPalette.bar.opacity(0.55), lineWidth: 1.5)
        }
        // At the bottom edge: at the top it would run into the notification.
        .overlay(alignment: .bottom) {
            Text("SIMULAÇÃO")
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(ElectionPalette.bar, in: .capsule)
                .overlay(Capsule().strokeBorder(.black.opacity(0.25), lineWidth: 1))
                .offset(y: 10)
        }
        .shadow(color: ElectionPalette.bar.opacity(0.25), radius: 14)
    }

    /// The picked wallpaper, darkened toward the bottom, as iOS does behind notifications,
    /// and a little at the top so the white clock reads on a light wallpaper.
    private var wallpaperBackground: some View {
        Group {
            if let image = wallpaper {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.08, blue: 0.22),
                        Color(red: 0.20, green: 0.11, blue: 0.33),
                        Color(red: 0.55, green: 0.24, blue: 0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.28), location: 0),
                    .init(color: .black.opacity(0.08), location: 0.35),
                    .init(color: .black.opacity(0.2), location: 0.5),
                    .init(color: .black.opacity(0.6), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Timeline

/// The count as the Live Activity would get it on election night, one push at a time, as a
/// function of time. The numbers are invented: the lead changes hands evenly through the
/// lap, and the count stops short of the end so the video never shows a final result.
enum ElectionStoriesTimeline {

    struct Frame {
        let state: ElectionActivityAttributes.ContentState
        /// The next state while the leader changes, faded in over `state`.
        let incomingState: ElectionActivityAttributes.ContentState?
        let incomingOpacity: Double
        /// Where the beacon is in its beat, 0 to 1.
        let beacon: Double
        let clock: String
        let date: String
        /// How long ago the "A apuração começou" push arrived, as iOS writes it.
        let notificationAge: String
    }

    private struct Update {
        let counted: Double
        let lula: Double
        let flavio: Double
        /// Brasília time on October 4.
        let hour: Int
        let minute: Int
    }

    private static let updates: [Update] = [
        Update(counted: 2.31, lula: 41.27, flavio: 46.10, hour: 17, minute: 8),
        Update(counted: 9.84, lula: 43.02, flavio: 45.11, hour: 17, minute: 21),
        Update(counted: 21.47, lula: 44.65, flavio: 44.12, hour: 17, minute: 35),
        Update(counted: 34.90, lula: 45.08, flavio: 43.77, hour: 17, minute: 52),
        Update(counted: 47.36, lula: 44.21, flavio: 44.59, hour: 18, minute: 10),
        Update(counted: 58.82, lula: 43.95, flavio: 44.83, hour: 18, minute: 31),
        Update(counted: 69.13, lula: 44.71, flavio: 44.40, hour: 18, minute: 55),
        Update(counted: 78.66, lula: 44.93, flavio: 44.38, hour: 19, minute: 22),
        Update(counted: 87.05, lula: 44.52, flavio: 44.61, hour: 19, minute: 58),
        Update(counted: 94.48, lula: 44.58, flavio: 44.55, hour: 20, minute: 41)
    ]

    /// Time on screen for each update, and how long the change to it takes.
    private static let slot = 1.5
    private static let transition = 0.45
    /// The beacon's beat. Divides the loop evenly, so the rings don't jump at the seam.
    private static let beaconPeriod = 2.5
    /// When the push went out, Brasília time.
    private static let notificationHour = 17
    private static let notificationMinute = 5

    static let loopDuration = slot * Double(updates.count)

    private static let timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .current

    static func frame(at time: TimeInterval) -> Frame {
        // Shifted by one transition, so the video opens on a settled first update and the
        // last frames fade back into it: the loop closes without a jump.
        let t = (time + transition).truncatingRemainder(dividingBy: loopDuration)
        let index = Int(t / slot)
        let target = updates[index]
        let previous = updates[(index + updates.count - 1) % updates.count]
        let sinceUpdate = t - Double(index) * slot
        let progress = easeInOut(min(sinceUpdate / transition, 1))

        let counted = mix(previous.counted, target.counted, progress)
        let lula = mix(previous.lula, target.lula, progress)
        let flavio = mix(previous.flavio, target.flavio, progress)
        // Texts switch halfway through the change, like the digits rolling over.
        let shown = progress < 0.5 ? previous : target
        let updatedAt = date(hour: shown.hour, minute: shown.minute)

        // The leader always sits on the left, as in the real activity. While the lead changes
        // hands, the old order sits under the new one fading in.
        let leaderBefore = previous.lula >= previous.flavio
        let leaderAfter = target.lula >= target.flavio
        let leaderChanges = leaderBefore != leaderAfter && progress < 1
        let state = state(counted: counted, lula: lula, flavio: flavio, lulaFirst: leaderChanges ? leaderBefore : leaderAfter, updatedAt: updatedAt)

        return Frame(
            state: state,
            incomingState: leaderChanges
                ? Self.state(counted: counted, lula: lula, flavio: flavio, lulaFirst: leaderAfter, updatedAt: updatedAt)
                : nil,
            incomingOpacity: progress,
            beacon: time.truncatingRemainder(dividingBy: beaconPeriod) / beaconPeriod,
            clock: Date(timeIntervalSince1970: updatedAt).formatted(Date.FormatStyle(timeZone: timeZone).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)),
            date: "domingo, 4 de outubro",
            notificationAge: age(minutes: Int((updatedAt - date(hour: notificationHour, minute: notificationMinute)) / 60))
        )
    }

    private static func state(counted: Double, lula: Double, flavio: Double, lulaFirst: Bool, updatedAt: Double) -> ElectionActivityAttributes.ContentState {
        let lulaCandidate = ElectionActivityAttributes.Candidate(number: 13, name: "LULA", party: "PT", percent: lula, status: .counting, colorHex: nil)
        let flavioCandidate = ElectionActivityAttributes.Candidate(number: 22, name: "FLAVIO BOLSONARO", party: "PL", percent: flavio, status: .counting, colorHex: nil)
        return ElectionActivityAttributes.ContentState(
            sectionsCountedPercent: counted,
            isFinal: false,
            updatedAt: updatedAt,
            candidates: lulaFirst ? [lulaCandidate, flavioCandidate] : [flavioCandidate, lulaCandidate]
        )
    }

    private static func date(hour: Int, minute: Int) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: hour, minute: minute)) ?? .now
        return date.timeIntervalSince1970
    }

    private static func age(minutes: Int) -> String {
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "há \(minutes) min" }
        return "há \(minutes / 60) h"
    }

    private static func mix(_ a: Double, _ b: Double, _ progress: Double) -> Double {
        a + (b - a) * progress
    }

    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }
}

// MARK: - Export

enum ElectionStoriesVideoExporter {

    enum ExportError: LocalizedError {
        case frameRenderFailed
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .frameRenderFailed: "Não foi possível desenhar um quadro do vídeo."
            case .writeFailed(let reason): "Não foi possível gravar o vídeo: \(reason)"
            }
        }
    }

    static let fps: Int32 = 30

    /// Renders every frame with `ImageRenderer` and writes an H.264 MP4, 1080 × 1920.
    @MainActor
    static func export(laps: Int, wallpaper: UIImage?, progress: (Double) -> Void) async throws -> URL {
        let size = ElectionStoriesFrame.exportSize
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Apuracao-ao-Vivo-Stories.mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000]
        ])
        input.expectsMediaDataInRealTime = false
        // IOSurface-backed BGRA, as in ShareClipGenerator: VideoToolbox rejects other buffers.
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
        ])
        writer.add(input)
        guard writer.startWriting() else {
            throw ExportError.writeFailed(writer.error?.localizedDescription ?? "startWriting")
        }
        writer.startSession(atSourceTime: .zero)

        let context = CIContext()
        let totalFrames = Int((ElectionStoriesTimeline.loopDuration * Double(laps) * Double(fps)).rounded())
        for index in 0..<totalFrames {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            let renderer = ImageRenderer(content: ElectionStoriesFrame(time: Double(index) / Double(fps), wallpaper: wallpaper))
            renderer.scale = size.width / ElectionStoriesFrame.size.width
            guard let image = renderer.cgImage, let pool = adaptor.pixelBufferPool else {
                writer.cancelWriting()
                throw ExportError.frameRenderFailed
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
            guard let pixelBuffer else {
                writer.cancelWriting()
                throw ExportError.frameRenderFailed
            }
            // The render can come out a pixel off 1920 from rounding: stretch it to the frame.
            let fitted = CIImage(cgImage: image).transformed(by: CGAffineTransform(
                scaleX: size.width / CGFloat(image.width),
                y: size.height / CGFloat(image.height)
            ))
            context.render(fitted, to: pixelBuffer)
            guard adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(index), timescale: fps)) else {
                throw ExportError.writeFailed(writer.error?.localizedDescription ?? "append")
            }
            progress(Double(index + 1) / Double(totalFrames))
            // Lets the progress bar draw between frames.
            await Task.yield()
        }

        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw ExportError.writeFailed(writer.error?.localizedDescription ?? "status \(writer.status.rawValue)")
        }
        return url
    }
}

// MARK: - Preview

#Preview("Screen") {
    NavigationStack {
        ElectionStoriesVideoView()
    }
}

#Preview("Frame, settled") {
    ElectionStoriesFrame(time: 0)
}

#Preview("Frame, leader changing") {
    ElectionStoriesFrame(time: 1.25)
}
