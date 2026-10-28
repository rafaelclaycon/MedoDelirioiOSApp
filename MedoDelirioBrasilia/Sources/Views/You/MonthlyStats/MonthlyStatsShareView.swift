//
//  MonthlyStatsShareView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/10/26.
//

import SwiftUI
import Kingfisher

/// What gets shared from Seu Mês: a whole month, or one card of its feed.
enum MonthlyShareContent {
    case month(MonthlyStats)
    case highlight(MonthlyHighlight)
}

/// The content at the moment someone taps "Compartilhar", with who they are, so the
/// picture doesn't change while they pick a format.
struct MonthlyStatsShareSnapshot: Identifiable {

    let id = UUID()
    let content: MonthlyShareContent
    let nickname: String?
    /// The profile photo's URL; the picture is loaded by the share screen.
    let avatarPhoto: String?
    /// The user's own photo, which wins over `avatarPhoto`.
    var customPhoto: Data? = nil

    @MainActor
    init(content: MonthlyShareContent, profile: ProfileStore) {
        self.content = content
        self.nickname = profile.nickname
        self.avatarPhoto = profile.avatarAuthorID.flatMap { try? LocalDatabase.shared.author(withId: $0)?.photo }
        self.customPhoto = profile.customPhoto
    }

    init(content: MonthlyShareContent, nickname: String?, avatarPhoto: String?) {
        self.content = content
        self.nickname = nickname
        self.avatarPhoto = avatarPhoto
    }

    /// "Meu Setembro no Medo e Delírio", "Meu Outubro até agora no Medo e Delírio", or a
    /// highlight's headline.
    var shareTitle: String {
        switch content {
        case .month(let stats):
            let month = stats.isInProgress ? "\(stats.month.name) até agora" : stats.month.name
            return "Meu \(month) no Medo e Delírio"
        case .highlight(let highlight):
            return highlight.headline
        }
    }

    /// For analytics: "month(2026-9)" or "highlight(authorShare)".
    var analyticsName: String {
        switch content {
        case .month(let stats): "month(\(stats.month.id))"
        case .highlight(let highlight): "highlight(\(highlight.kind.rawValue))"
        }
    }

    /// The pictures the card needs downloaded before it can be drawn.
    var artworkURLs: [URL] {
        guard case .highlight(let highlight) = content else { return [] }
        switch highlight.artwork {
        case .author(let photo), .sound(let photo):
            return photo.flatMap(URL.init(string:)).map { [$0] } ?? []
        case .episode(let url):
            return url.map { [$0] } ?? []
        case .episodes(let urls):
            return urls.prefix(4).compactMap { $0 }
        case .symbol:
            return []
        }
    }
}

/// Shows exactly what gets shared, a picture of the month, and lets people pick the
/// square or the stories format before sharing. Same flow as the games' and the election's.
struct MonthlyStatsShareView: View {

    let snapshot: MonthlyStatsShareSnapshot

    @Environment(\.dismiss) private var dismiss

    @State private var format: ShareImageFormat = .stories
    @State private var avatar: UIImage?
    @State private var artwork: [URL: UIImage] = [:]
    @State private var shareItem: ImageShareItemSource?
    @State private var isRendering = false

    private var isPreparingShare: Bool {
        isRendering || shareItem != nil
    }

    private var card: MonthlyStatsShareCard {
        MonthlyStatsShareCard(snapshot: snapshot, format: format, avatar: avatar, artwork: artwork)
    }

    private var explanation: String {
        switch snapshot.content {
        case .month: "Uma imagem com o resumo do seu mês, pra postar nos Stories ou mandar pros amigos."
        case .highlight: "Uma imagem com este destaque, pra postar nos Stories ou mandar pros amigos."
        }
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
                    StoriesTagCallout(tint: .darkerGreen, offersAppLink: true)
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
                .tint(.darkerGreen)
                .disabled(isPreparingShare)
            }
            .padding(.spacing(.large))
            .navigationTitle(snapshot.content.isMonth ? "Compartilhar Meu Mês" : "Compartilhar Destaque")
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
                        originatingScreen: "MonthlyStatsShareView",
                        action: "didShareMonthlyStats(\(snapshot.analyticsName), format: \(format.rawValue), to: \(destination))"
                    )
                }
                dismiss()
            }
            // `ImageRenderer` draws what's on hand, so the photos are fetched (usually from
            // the cache) before the picture can include them.
            .task {
                await loadAvatar()
            }
            .task {
                await loadArtwork()
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

    private func loadArtwork() async {
        for url in snapshot.artworkURLs {
            if let image = try? await KingfisherManager.shared.retrieveImage(with: url).image {
                artwork[url] = image
            }
        }
    }
}

private extension MonthlyShareContent {

    var isMonth: Bool {
        if case .month = self { return true }
        return false
    }
}

// MARK: - Card

/// A picture of someone's month in the app's greens: the month, its numbers, the Vírgulas
/// that stood out, the episode, who it belongs to and the app's credit. Stories keep the
/// top and bottom clear, where Instagram draws its own controls.
struct MonthlyStatsShareCard: View {

    let snapshot: MonthlyStatsShareSnapshot
    let format: ShareImageFormat
    let avatar: UIImage?
    var artwork: [URL: UIImage] = [:]

    @MainActor
    func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3
        return renderer.uiImage
    }

    /// Only read by the month's layouts.
    private var stats: MonthlyStats {
        if case .month(let stats) = snapshot.content { return stats }
        preconditionFailure("A highlight has no month layout")
    }

    private var hasPlayer: Bool {
        avatar != nil || snapshot.nickname != nil
    }

    /// Shared ones come first: they're the reason the app exists. A month with only plays
    /// shows those instead.
    private var topSounds: (title: String, items: [TopChartItem]) {
        if !stats.topSharedSounds.isEmpty {
            return ("Minhas mais compartilhadas", Array(stats.topSharedSounds.prefix(3)))
        }
        return ("Minhas mais tocadas", Array(stats.topPlayedSounds.prefix(3)))
    }

    /// Up to three numbers, the most telling first. Days in the app fill in for a month
    /// without one of the others.
    private var numbers: [(value: String, label: String)] {
        var numbers: [(value: String, label: String)] = []
        if stats.shareCount > 0 {
            numbers.append((MonthlyStats.formattedNumber(stats.shareCount), stats.shareCount == 1 ? "compartilhamento" : "compartilhamentos"))
        }
        if stats.hasEpisodes {
            numbers.append((stats.formattedListeningTime, "de episódios"))
        }
        if stats.playCount > 0 {
            numbers.append((MonthlyStats.formattedNumber(stats.playCount), stats.playCount == 1 ? "Vírgula tocada" : "Vírgulas tocadas"))
        }
        numbers.append(("\(stats.activeDays)", stats.activeDays == 1 ? "dia no app" : "dias no app"))
        return Array(numbers.prefix(3))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.darkestGreen, Color(red: 0.0, green: 0.38, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            // A soft light behind the month's name, so the top doesn't read as a flat slab.
            RadialGradient(
                colors: [Color.brightGreen.opacity(0.35), .clear],
                center: UnitPoint(x: 0.5, y: 0.2),
                startRadius: 0,
                endRadius: 260
            )

            switch (snapshot.content, format) {
            case (.month, .square): square
            case (.month, .stories): stories
            case (.highlight(let highlight), .square): highlightSquare(highlight)
            case (.highlight(let highlight), .stories): highlightStories(highlight)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // A picture has a fixed size: the same text whatever size the person reads at.
        .dynamicTypeSize(.large)
        .frame(width: format.size.width, height: format.size.height)
    }

    /// A poster: the month's name as the headline, who it belongs to, the numbers, the
    /// Vírgulas and the episode, then the app's credit. The flexible spaces split what's
    /// left evenly, whatever the month has in it.
    private var stories: some View {
        VStack(spacing: 0) {
            pill()

            Spacer(minLength: 10)

            monthTitle(nameSize: 64, detailSize: 18)

            if hasPlayer {
                player(avatarSize: 40, nameSize: 17)
                    .padding(.top, 14)
            }

            Spacer(minLength: 10)

            numbersRow(valueSize: 28, labelSize: 11)

            Spacer(minLength: 10)

            if !topSounds.items.isEmpty {
                soundList(titleSize: 13, nameSize: 16, authorSize: 12, rowSpacing: 8)
            }

            if let episode = stats.topEpisode {
                episodeBlock(episode)
                    .padding(.top, topSounds.items.isEmpty ? 0 : 16)
            }

            Spacer(minLength: 10)

            HStack(alignment: .center, spacing: 12) {
                Image("podcast_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)

                Spacer(minLength: 0)

                // The app's full name, iOS included: it sets it apart from the podcast,
                // and saves explaining to Android users why they can't find it.
                Text("Veja o seu no app Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, Self.storiesVerticalPadding)
    }

    /// Less than `ShareImageFormat.storiesSafeVerticalPadding`: the pill and the credit can
    /// sit where Instagram's top and bottom bars fade in, and the blocks in between get the
    /// room instead of crowding the middle.
    static let storiesVerticalPadding: CGFloat = 52

    /// The same blocks, tighter, without the episode: a square has room for the month,
    /// its numbers and the Vírgulas.
    private var square: some View {
        VStack(spacing: 0) {
            monthTitle(nameSize: 34, detailSize: 13)

            Spacer(minLength: 8)

            numbersRow(valueSize: 22, labelSize: 10)

            Spacer(minLength: 8)

            if !topSounds.items.isEmpty {
                soundList(titleSize: 11, nameSize: 13, authorSize: 10, rowSpacing: 5)
            } else if let episode = stats.topEpisode {
                episodeBlock(episode)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Image("IconePadrao")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if hasPlayer {
                    player(avatarSize: 22, nameSize: 12)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    // MARK: - Highlight Layouts

    /// The feed card as a poster: the week, the big picture, the headline and the sentence.
    private func highlightStories(_ highlight: MonthlyHighlight) -> some View {
        VStack(spacing: 0) {
            pill(highlight.dateLabel)

            Spacer(minLength: 16)

            // Shrinks before the text does when the sentence runs long, and takes its full
            // size ahead of the spaces when there's room.
            artworkImage(highlight.artwork)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 230, maxHeight: 230)
                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                .layoutPriority(1)

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                Text(highlight.headline)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(highlight.detailText(nameColor: .brightYellow))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
            }
            .multilineTextAlignment(.center)
            // The flexible spaces around would otherwise squeeze the headline to one line.
            .fixedSize(horizontal: false, vertical: true)

            if hasPlayer {
                player(avatarSize: 32, nameSize: 15)
                    .padding(.top, 16)
            }

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 12) {
                Image("podcast_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)

                Spacer(minLength: 0)

                Text("Veja o seu no app Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, ShareImageFormat.storiesSafeVerticalPadding)
    }

    /// Picture on the left, words on the right: a square has no room to stack them.
    private func highlightSquare(_ highlight: MonthlyHighlight) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(highlight.dateLabel.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 16) {
                artworkImage(highlight.artwork)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                VStack(alignment: .leading, spacing: 6) {
                    Text(highlight.headline)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)

                    Text(highlight.detailText(nameColor: .brightYellow))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(5)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Image("IconePadrao")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(.rect(cornerRadius: 6))
                Text("Medo e Delírio iOS")
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if hasPlayer {
                    player(avatarSize: 22, nameSize: 12)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    /// The highlight's picture from what the share screen downloaded. `SeuMesArtwork`
    /// can't be used: a picture is drawn in one pass, with no time to download.
    @ViewBuilder
    private func artworkImage(_ artwork: MonthlyHighlight.Artwork) -> some View {
        switch artwork {
        case .author(let photo):
            loadedImage(photo.flatMap(URL.init(string:)), placeholder: "person.fill")
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))

        case .sound(let photo):
            loadedImage(photo.flatMap(URL.init(string:)), placeholder: "waveform")
                .clipShape(.rect(cornerRadius: 8))

        case .episode(let url):
            loadedImage(url, placeholder: "headphones")
                .clipShape(.rect(cornerRadius: 8))

        case .episodes(let urls):
            let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(urls.prefix(4).enumerated()), id: \.offset) { _, url in
                    loadedImage(url, placeholder: "headphones")
                        .clipShape(.rect(cornerRadius: 6))
                }
            }

        case .symbol(let name):
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.10, blue: 0.42), Color(red: 0.42, green: 0.22, blue: 0.70)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .padding(36)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func loadedImage(_ url: URL?, placeholder: String) -> some View {
        Color.white.opacity(0.12)
            .overlay {
                if let url, let image = artwork[url] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    GeometryReader { proxy in
                        Image(systemName: placeholder)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width * 0.35, height: proxy.size.width * 0.35)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .clipped()
    }

    // MARK: - Blocks

    /// What this is in a faint outline, without competing with what's under it.
    private func pill(_ text: String = "Meu mês no Medo e Delírio") -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
    }

    private func monthTitle(nameSize: CGFloat, detailSize: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(stats.month.name)
                .font(.system(size: nameSize, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

            Text(stats.isInProgress ? "até agora" : String(stats.month.year))
                .font(.system(size: detailSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    /// The numbers side by side, all the same size, labels on one line: each shrinking on
    /// its own to fit would leave "4h 10min" smaller than "18" and its label higher.
    private func numbersRow(valueSize: CGFloat, labelSize: CGFloat) -> some View {
        let size = Self.sharedValueSize(for: numbers.map(\.value), base: valueSize)
        let longestLabel = numbers.map(\.label.count).max() ?? 0
        let label = longestLabel > 14 ? labelSize * 0.9 : labelSize
        return HStack(alignment: .top, spacing: 8) {
            ForEach(numbers, id: \.label) { number in
                VStack(spacing: 2) {
                    Text(number.value)
                        .font(.system(size: size, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(height: size * 1.25)

                    // One line: two would break "compartilhamentos" mid-word.
                    Text(number.label)
                        .font(.system(size: label, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// One size for every number in the row, set by the longest, so a duration like
    /// "4h 10min" doesn't make the row uneven.
    static func sharedValueSize(for values: [String], base: CGFloat) -> CGFloat {
        let longest = values.map(\.count).max() ?? 0
        switch longest {
        case ...5: return base
        case ...7: return base * 0.86
        default: return base * 0.78
        }
    }

    private func soundList(titleSize: CGFloat, nameSize: CGFloat, authorSize: CGFloat, rowSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text(topSounds.title.uppercased())
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))

            ForEach(topSounds.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.rankNumber)
                        .font(.system(size: nameSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brightYellow)
                        .frame(width: nameSize, alignment: .leading)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.contentName)
                            .font(.system(size: nameSize, weight: .bold))
                            .lineLimit(1)

                        Text(item.contentAuthorName)
                            .font(.system(size: authorSize, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func episodeBlock(_ episode: MonthlyStats.RankedEpisode) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("EPISÓDIO DO MÊS")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.brightYellow)
                    .frame(width: 16, alignment: .leading)

                Text(episode.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func player(avatarSize: CGFloat, nameSize: CGFloat) -> some View {
        HStack(spacing: 8) {
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
}

// MARK: - Preview

private let previewStats = MonthlyStats(
    month: StatsMonth(year: 2026, month: 9),
    isInProgress: false,
    shareCount: 47,
    playCount: 112,
    secondsListened: 12_000,
    episodesFinished: 3,
    activeDays: 14,
    topSharedSounds: [
        TopChartItem(id: "1", rankNumber: "1", contentId: "a", contentName: "Uma Vírgula de exemplo", contentAuthorId: "x", contentAuthorName: "Autor de Exemplo", shareCount: 9),
        TopChartItem(id: "2", rankNumber: "2", contentId: "b", contentName: "Outra Vírgula", contentAuthorId: "y", contentAuthorName: "Outro Autor", shareCount: 6),
        TopChartItem(id: "3", rankNumber: "3", contentId: "c", contentName: "Uma Vírgula com um título bem comprido para testar", contentAuthorId: "z", contentAuthorName: "Terceiro Autor", shareCount: 4)
    ],
    topPlayedSounds: [],
    topAuthors: [],
    topEpisodes: [
        MonthlyStats.RankedEpisode(id: "e", title: "Um episódio de exemplo com um título comprido que ocupa duas linhas", imageURL: nil, secondsListened: 5_400)
    ],
    highlights: []
)

private let previewHighlight = MonthlyHighlight(
    kind: .authorShare,
    week: DateInterval(start: .now, duration: 7 * 86_400),
    headline: "40% dos seus compartilhamentos",
    detail: "Nesta semana, 6 das Vírgulas que você compartilhou foram de Autor de Exemplo.",
    emphasized: ["Autor de Exemplo"],
    artwork: .author(photo: nil),
    dateLabel: "12 a 18 de out. de 2026"
)

#Preview("Share Screen") {
    MonthlyStatsShareView(
        snapshot: MonthlyStatsShareSnapshot(content: .month(previewStats), nickname: "Rafa", avatarPhoto: nil)
    )
}

#Preview("Stories Card") {
    MonthlyStatsShareCard(
        snapshot: MonthlyStatsShareSnapshot(content: .month(previewStats), nickname: "Rafa", avatarPhoto: nil),
        format: .stories,
        avatar: nil
    )
}

#Preview("Highlight, Stories") {
    MonthlyStatsShareCard(
        snapshot: MonthlyStatsShareSnapshot(content: .highlight(previewHighlight), nickname: "Rafa", avatarPhoto: nil),
        format: .stories,
        avatar: nil
    )
}

#Preview("Highlight, Square") {
    MonthlyStatsShareCard(
        snapshot: MonthlyStatsShareSnapshot(content: .highlight(previewHighlight), nickname: nil, avatarPhoto: nil),
        format: .square,
        avatar: nil
    )
}
