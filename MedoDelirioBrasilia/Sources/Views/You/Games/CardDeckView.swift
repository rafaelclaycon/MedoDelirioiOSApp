//
//  CardDeckView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import SwiftUI
import Kingfisher

/// The face game's photos as a deck being dealt: the current round face up in front,
/// the next ones face down behind it, peeking out to the sides. Answering and moving
/// on throws the front card off (right when you got it, left when you didn't), the
/// deck moves up and the new front card flips over.
struct CardDeckView: View {

    let session: GameSession
    let photoFailed: (GameRound.ID, String) -> Void
    /// The front photo is on screen, so the clock can start.
    let photoLoaded: (GameRound.ID) -> Void

    /// Square, whatever shape the photo is.
    static let cardSide: CGFloat = 230
    /// The front card and two behind it.
    private static let visibleDepth = 3

    /// False until the deck has been dealt, so the first card flips over on screen.
    @State private var isDealt = false
    /// Shrinks the deck to the height it's given, so the options still fit on smaller
    /// iPhones.
    @State private var scale: CGFloat = 1

    /// The deck's full size, cards behind included: they tilt out to the sides.
    private static let deckSize = CGSize(width: cardSide + 48, height: cardSide + 16)

    private var visibleRounds: [GameRound] {
        let end = min(session.index + Self.visibleDepth, session.rounds.count)
        guard session.index < end else { return [] }
        return Array(session.rounds[session.index..<end])
    }

    var body: some View {
        Color.clear
            .frame(minHeight: 160)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                deck
                    .scaleEffect(scale)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                scale = min(1, height / Self.deckSize.height)
            }
    }

    private var deck: some View {
        ZStack {
            ForEach(Array(visibleRounds.enumerated()), id: \.element.id) { depth, round in
                FlippingCard(
                    angle: depth == 0 && isDealt ? 0 : 180,
                    round: round,
                    kind: session.kind,
                    side: Self.cardSide,
                    reveal: depth == 0 && session.isRevealed ? (session.pickedCorrectly ? .right : .wrong) : nil,
                    clockStart: depth == 0 ? session.roundStartedAt : nil,
                    photoFailed: photoFailed,
                    photoLoaded: photoLoaded
                )
                .scaleEffect(1 - 0.06 * Double(depth))
                .rotationEffect(.degrees(Self.tilt(depth)))
                .offset(x: Self.sideOffset(depth), y: 6 * Double(depth))
                .zIndex(-Double(depth))
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .modifier(
                        active: Discard(direction: session.pickedCorrectly ? 1 : -1, isGone: true),
                        identity: Discard(direction: session.pickedCorrectly ? 1 : -1, isGone: false)
                    )
                ))
            }
        }
        .frame(width: Self.deckSize.width, height: Self.deckSize.height)
        // A new game, or a first card swapped for a broken photo, is dealt again.
        .task(id: session.rounds.first?.id) {
            isDealt = false
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                isDealt = true
            }
        }
    }

    /// Alternating sides, like a fanned deck.
    private static func tilt(_ depth: Int) -> Double {
        switch depth {
        case 0: 0
        case 1: 5
        default: -5
        }
    }

    private static func sideOffset(_ depth: Int) -> Double {
        switch depth {
        case 0: 0
        case 1: 18
        default: -18
        }
    }
}

// MARK: - Discard

extension CardDeckView {

    /// The front card leaving: thrown off to one side, spinning a little as it goes.
    struct Discard: ViewModifier {

        /// 1 to the right, -1 to the left.
        let direction: Double
        let isGone: Bool

        func body(content: Content) -> some View {
            content
                .rotationEffect(.degrees(isGone ? 24 * direction : 0))
                .offset(x: isGone ? 460 * direction : 0, y: isGone ? 50 : 0)
                .opacity(isGone ? 0 : 1)
        }
    }
}

// MARK: - Flipping Card

extension CardDeckView {

    enum Reveal {
        case right, wrong
    }

    /// A card that turns over around its vertical axis. `angle` animates, so the face
    /// can switch from back to front exactly when the card is edge-on.
    @Animatable
    struct FlippingCard: View {

        /// 0 is face up, 180 face down.
        var angle: Double
        @AnimatableIgnored let round: GameRound
        @AnimatableIgnored let kind: GameKind
        @AnimatableIgnored let side: CGFloat
        @AnimatableIgnored let reveal: Reveal?
        /// When the front photo started showing, for the pixelation. Nil while it hasn't.
        @AnimatableIgnored let clockStart: Date?
        @AnimatableIgnored let photoFailed: (GameRound.ID, String) -> Void
        @AnimatableIgnored let photoLoaded: (GameRound.ID) -> Void

        private static let cornerRadius: CGFloat = 26

        var body: some View {
            ZStack {
                if angle < 90 {
                    front
                } else {
                    // Mirrored, so it reads the right way round once turned past 90°.
                    CardBack(kind: kind)
                        .scaleEffect(x: -1)
                }
            }
            // Sized before clipping: a wide photo filling the card would otherwise
            // stretch it, and the clip with it.
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
        }

        @ViewBuilder
        private var front: some View {
            if case .photo(let photo) = round.prompt {
                // A fixed square the photo fills and is cropped to, not the photo's own
                // shape.
                Color.clear
                    .overlay {
                        // Only the photo; the name and the badge drawn over it stay sharp.
                        PixelatedPhoto(
                            photo: photo,
                            start: clockStart,
                            isSharp: reveal != nil,
                            onLoaded: { photoLoaded(round.id) },
                            onFailed: { photoFailed(round.id, photo) }
                        )
                    }
                    .clipped()
                    .overlay(alignment: .bottomLeading) {
                        if reveal != nil {
                            nameCaption
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let reveal {
                            Image(systemName: reveal == .right ? "checkmark" : "xmark")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(reveal == .right ? Color.green : .red))
                                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                                .padding(.spacing(.small))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(reveal == nil ? "Foto de alguém do podcast" : "Foto de \(round.answer.name)")
            }
        }

        /// Who it was, over a dark fade at the bottom of the photo, once answered.
        private var nameCaption: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(reveal == .right ? "Acertou, é" : "Era")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))

                Text(round.answer.name)
                    .font(.system(.title3, design: .rounded))
                    .bold()
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.spacing(.medium))
            .padding(.top, .spacing(.large))
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    /// The front photo, drawn in blocks that shrink each second of the reveal: fully
    /// blocky until the clock starts, so it can't be recognized before it counts, and
    /// sharp once answered.
    ///
    /// Each step is the photo drawn into a tiny square image, one pixel per block (so
    /// each block is the average color of its area), then scaled up without smoothing.
    /// No shader, so building the app doesn't need the Metal toolchain.
    struct PixelatedPhoto: View {

        let photo: String
        let start: Date?
        let isSharp: Bool
        let onLoaded: () -> Void
        let onFailed: () -> Void

        @State private var image: UIImage?
        @State private var blocks = BlockCache()

        var body: some View {
            Group {
                if let image {
                    TimelineView(.periodic(from: .now, by: 0.25)) { context in
                        let size = blockSize(at: context.date)
                        if size <= 1 {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(uiImage: blocks.image(from: image, blockSize: size, side: CardDeckView.cardSide))
                                .resizable()
                                .interpolation(.none)
                                .scaledToFill()
                        }
                    }
                } else {
                    ZStack {
                        Color(.secondarySystemGroupedBackground)
                        ProgressView()
                    }
                }
            }
            .task(id: photo) {
                await load()
            }
        }

        private func blockSize(at date: Date) -> Double {
            if isSharp { return 1 }
            guard let start else { return GameScoring.pixelSteps[0] }
            return GameScoring.pixelSize(afterElapsed: date.timeIntervalSince(start))
        }

        private func load() async {
            guard let url = URL(string: photo) else {
                onFailed()
                return
            }
            do {
                let result = try await KingfisherManager.shared.retrieveImage(
                    with: url,
                    options: [.requestModifier(AnyModifier { request in
                        var request = request
                        request.timeoutInterval = GameView.photoTimeout
                        return request
                    })]
                )
                image = result.image
                onLoaded()
            } catch {
                // Leaving the round mid-load cancels it; that's not a broken photo.
                guard !Task.isCancelled else { return }
                onFailed()
            }
        }
    }

    /// The blocky versions of one photo, made once per block size. A reference type in
    /// `@State`, so filling it while drawing doesn't count as a state change.
    final class BlockCache {

        private var photo: UIImage?
        private var images: [Double: UIImage] = [:]

        func image(from photo: UIImage, blockSize: Double, side: CGFloat) -> UIImage {
            if photo !== self.photo {
                self.photo = photo
                images = [:]
            }
            if let cached = images[blockSize] {
                return cached
            }
            let made = Self.blocky(photo, blocksPerSide: max(1, Int((side / blockSize).rounded())))
            images[blockSize] = made
            return made
        }

        /// The photo cropped to a square like the card's aspect fill, at one pixel per
        /// block.
        private static func blocky(_ photo: UIImage, blocksPerSide: Int) -> UIImage {
            let side = CGFloat(blocksPerSide)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
                let scale = max(side / photo.size.width, side / photo.size.height)
                let size = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
                let origin = CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2)
                photo.draw(in: CGRect(origin: origin, size: size))
            }
        }
    }

    /// The back of a card: the game's colors and symbol, so the deck looks like one.
    struct CardBack: View {

        let kind: GameKind

        var body: some View {
            ZStack {
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.45, 0.55], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                    colors: kind.meshColors
                )

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 2)
                    .padding(.spacing(.small))

                Image(systemName: kind.systemImage)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityHidden(true)
        }
    }
}
