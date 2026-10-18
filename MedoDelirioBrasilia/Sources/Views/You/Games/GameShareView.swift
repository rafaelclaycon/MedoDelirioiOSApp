//
//  GameShareView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import SwiftUI
import Kingfisher

/// A finished game at the moment someone taps "Compartilhar resultado", with who played
/// it, so the picture doesn't change while they pick a format.
struct GameShareSnapshot: Identifiable {

    let id = UUID()
    let kind: GameKind
    let hits: Int
    let points: Int
    let total: Int
    let isNewRecord: Bool
    let nickname: String?
    /// The profile photo's URL; the picture is loaded by the share screen.
    let avatarPhoto: String?
    /// The user's own photo, which wins over `avatarPhoto`.
    var customPhoto: Data? = nil

    @MainActor
    init(session: GameSession, isNewRecord: Bool, profile: ProfileStore) {
        self.kind = session.kind
        self.hits = session.hits
        self.points = session.points
        self.total = session.rounds.count
        self.isNewRecord = isNewRecord
        self.nickname = profile.nickname
        self.avatarPhoto = profile.avatarAuthorID.flatMap { try? LocalDatabase.shared.author(withId: $0)?.photo }
        self.customPhoto = profile.customPhoto
    }

    init(kind: GameKind, hits: Int, points: Int, total: Int, isNewRecord: Bool, nickname: String?, avatarPhoto: String?) {
        self.kind = kind
        self.hits = hits
        self.points = points
        self.total = total
        self.isNewRecord = isNewRecord
        self.nickname = nickname
        self.avatarPhoto = avatarPhoto
    }

    /// The big number: points for the face game, right answers for the voice game.
    var scoreText: String {
        switch kind.scoring {
        case .hits: "\(hits) de \(total)"
        case .points: GameScoring.formattedPoints(points)
        }
    }

    /// The share sheet's header, e.g. "De quem é essa fuça? · 7.450 pontos".
    var shareTitle: String {
        "\(kind.title) · \(scoreText)"
    }
}

/// Shows exactly what gets shared, a picture of the result, and lets people pick the
/// square or the stories format before sharing. Same flow as the election's.
struct GameShareView: View {

    let snapshot: GameShareSnapshot

    @Environment(\.dismiss) private var dismiss

    @State private var format: ShareImageFormat = .stories
    @State private var avatar: UIImage?
    @State private var shareItem: ImageShareItemSource?
    @State private var isRendering = false

    private var isPreparingShare: Bool {
        isRendering || shareItem != nil
    }

    private var card: GameShareCard {
        GameShareCard(snapshot: snapshot, format: format, avatar: avatar)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: .spacing(.large)) {
                Text("Uma imagem com o resultado desta partida, pra postar nos Stories ou mandar pros amigos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Picker("Formato", selection: $format) {
                    ForEach(ShareImageFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                GeometryReader { proxy in
                    let size = format.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    card
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
                    StoriesTagCallout(tint: snapshot.kind.accentColor, offersAppLink: true)
                }

                Button {
                    isRendering = true
                    Task {
                        // Rendering blocks the main thread, so give the spinner a frame to
                        // show up first.
                        try? await Task.sleep(for: .milliseconds(50))
                        if let image = card.render() {
                            shareItem = ImageShareItemSource(image: image, title: snapshot.shareTitle)
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
                .buttonStyle(.glassProminent)
                .tint(snapshot.kind.accentColor)
                .disabled(isPreparingShare)
            }
            .padding(.spacing(.large))
            .navigationTitle("Compartilhar Resultado")
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
                let destination = activityType?.rawValue ?? "unknown"
                Task {
                    await AnalyticsService().send(
                        originatingScreen: "GameShareView",
                        action: "didShareGameResult(\(snapshot.kind.rawValue), format: \(format.rawValue), to: \(destination))"
                    )
                }
                dismiss()
            }
            // `ImageRenderer` draws what's on hand, so the photo is fetched (usually from
            // the cache) before the picture can include it.
            .task {
                await loadAvatar()
            }
        }
    }

    private func loadAvatar() async {
        if let data = snapshot.customPhoto, let image = UIImage(data: data) {
            avatar = image
            return
        }
        guard let photo = snapshot.avatarPhoto, let url = URL(string: photo) else { return }
        avatar = try? await KingfisherManager.shared.retrieveImage(with: url).image
    }
}

// MARK: - Card

/// A picture of a game's result in the game's colors: the game, the score, who played
/// it and the app's credit. Stories keep the top and bottom clear, where Instagram draws
/// its own controls.
struct GameShareCard: View {

    let snapshot: GameShareSnapshot
    let format: ShareImageFormat
    let avatar: UIImage?

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }

    /// About the height of Instagram's link sticker on a 1080 × 1920 story, plus a
    /// little air.
    static let linkStickerSpace: CGFloat = 62

    private var hasPlayer: Bool {
        avatar != nil || snapshot.nickname != nil
    }

    private var detail: String? {
        snapshot.kind.scoring == .points ? "Acertei \(snapshot.hits) de \(snapshot.total)." : nil
    }

    var body: some View {
        ZStack {
            GameEntryCard.Background(kind: snapshot.kind)
            // A little darker overall, so white text reads over the light corner too.
            Color.black.opacity(0.18)

            switch format {
            case .square: square
            case .stories: stories
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // A picture has a fixed size: the same text whatever size the person reads at.
        .dynamicTypeSize(.large)
        .frame(width: format.size.width, height: format.size.height)
    }

    /// A poster: the game as a small outlined pill at the top, the player and their
    /// score as the centerpiece (sized so even the fullest case, with photo, nickname,
    /// hits and a record, fits Instagram's safe area without shrinking), the dare below, then room for Instagram's link sticker
    /// and the app's credit. The two flexible spaces split what's left evenly around the
    /// centerpiece, whatever's shown in it.
    private var stories: some View {
        VStack(spacing: 0) {
            gamePill

            Spacer(minLength: 12)

            VStack(spacing: 14) {
                if hasPlayer {
                    player(avatarSize: 52, nameSize: 20)
                }

                storiesScore

                if snapshot.isNewRecord {
                    newRecordBadge(fontSize: 15)
                }
            }

            Spacer(minLength: 12)

            Text("Duvido você fazer melhor!")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            // Left empty for Instagram's link sticker, so the link to the app has a home
            // that doesn't cover the score. The share screen offers to copy the link.
            Color.clear
                .frame(height: Self.linkStickerSpace)

            HStack(alignment: .center, spacing: 12) {
                Image("podcast_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)

                Spacer(minLength: 0)

                // The app's full name, iOS included: it sets it apart from the podcast,
                // and saves explaining to Android users why they can't find it.
                Text("Jogue no app Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
        .padding(.vertical, ShareImageFormat.storiesSafeVerticalPadding)
    }

    /// The score as a poster reads it, top to bottom: "Fiz" / "7.450" / "pontos!", or
    /// "Acertei" / "7 de 10!". Stacked, the number gets the whole width instead of
    /// shrinking to fit a sentence on one line.
    private var storiesScore: some View {
        VStack(spacing: 4) {
            Text(snapshot.kind.scoring == .points ? "Fiz" : "Acertei")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            Text(snapshot.kind.scoring == .points
                 ? GameScoring.formattedNumber(snapshot.points)
                 : "\(snapshot.hits) de \(snapshot.total)!")
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

            if snapshot.kind.scoring == .points {
                Text(snapshot.points == 1 ? "ponto!" : "pontos!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }

            if let detail {
                Text(detail)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.top, 10)
            }
        }
    }

    /// The game's symbol and name on one line, in a faint outline: it says what this is
    /// without competing with the score.
    private var gamePill: some View {
        HStack(spacing: 8) {
            GameSymbol(kind: snapshot.kind, size: 14, style: .white)

            Text(snapshot.kind.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
    }

    /// Flexible spacers between the blocks, so the content fills the square however long
    /// the title and name are.
    private var square: some View {
        VStack(spacing: 0) {
            gameBadge(iconSize: 40, titleSize: 18)

            Spacer(minLength: 8)

            if hasPlayer {
                player(avatarSize: 36, nameSize: 14)
                    .padding(.bottom, 8)
            }

            score(size: 44, detailSize: 14)

            if snapshot.isNewRecord {
                newRecordBadge(fontSize: 12)
                    .padding(.top, 8)
            }

            // Under the score, as on Stories, where it reads as the punchline.
            Text("Duvido você fazer melhor!")
                .font(.system(size: 15, weight: .semibold))
                .padding(.top, 10)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Image("IconePadrao")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Jogos do Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
    }

    private func gameBadge(iconSize: CGFloat, titleSize: CGFloat) -> some View {
        VStack(spacing: iconSize * 0.2) {
            GameSymbol(kind: snapshot.kind, size: iconSize * 0.42, style: snapshot.kind.accentColor)
                .frame(width: iconSize, height: iconSize)
                .background(Circle().fill(.white))

            Text(snapshot.kind.title)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    private func player(avatarSize: CGFloat, nameSize: CGFloat) -> some View {
        HStack(spacing: 10) {
            if let avatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }

            if let nickname = snapshot.nickname {
                Text(nickname)
                    .font(.system(size: nameSize, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
    }

    private func score(size: CGFloat, detailSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            scoreSentence(size: size)
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)

            if let detail {
                Text(detail)
                    .font(.system(size: detailSize, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    /// First person, like the player is telling a friend, with the number itself big:
    /// "Fiz 7.450 pontos!" or "Acertei 8 de 10!".
    private func scoreSentence(size: CGFloat) -> Text {
        let big = Font.system(size: size, weight: .heavy, design: .rounded)
        switch snapshot.kind.scoring {
        case .points:
            let unit = snapshot.points == 1 ? "ponto" : "pontos"
            return Text("Fiz \(Text(GameScoring.formattedNumber(snapshot.points)).font(big)) \(unit)!")
        case .hits:
            return Text("Acertei \(Text("\(snapshot.hits) de \(snapshot.total)").font(big))!")
        }
    }

    private func newRecordBadge(fontSize: CGFloat) -> some View {
        Label("NOVO RECORDE", systemImage: "star.fill")
            .font(.system(size: fontSize, weight: .heavy))
            .foregroundStyle(snapshot.kind.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white))
    }
}

// MARK: - Preview

private let previewSnapshot = GameShareSnapshot(
    kind: .whoseFace,
    hits: 8,
    points: 7450,
    total: 10,
    isNewRecord: true,
    nickname: "Rafa",
    avatarPhoto: nil
)

#Preview("Share Screen") {
    GameShareView(snapshot: previewSnapshot)
}

#Preview("Stories Card") {
    GameShareCard(snapshot: previewSnapshot, format: .stories, avatar: nil)
}

#Preview("Square Card, Voice") {
    GameShareCard(
        snapshot: GameShareSnapshot(kind: .whoseVoice, hits: 7, points: 0, total: 10, isNewRecord: false, nickname: nil, avatarPhoto: nil),
        format: .square,
        avatar: nil
    )
}
