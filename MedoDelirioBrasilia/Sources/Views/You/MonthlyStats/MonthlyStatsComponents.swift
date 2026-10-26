//
//  MonthlyStatsComponents.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/10/26.
//

import SwiftUI
import Kingfisher

/// Cards on a grouped background, like the capsule it's modeled on, in light or dark as
/// the system is. The accents are deeper in light mode, where Spotify's bright ones would
/// wash out on white.
enum SeuMesPalette {

    static let background = Color(.systemGroupedBackground)
    static let card = Color(.secondarySystemGroupedBackground)
    static let green = adaptive(light: (0.00, 0.55, 0.22), dark: (0.12, 0.84, 0.38))
    static let blue = adaptive(light: (0.10, 0.40, 0.86), dark: (0.42, 0.64, 1.00))
    static let yellow = adaptive(light: (0.72, 0.49, 0.00), dark: (1.00, 0.85, 0.27))
    /// Names inside a highlight's sentence.
    static let name = adaptive(light: (0.06, 0.44, 0.58), dark: (0.58, 0.80, 0.88))
    static let cornerRadius: CGFloat = 10

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(UIColor { traits in
            let (red, green, blue) = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        })
    }
}

extension MonthlyHighlight {

    /// The sentence with its names in `color`.
    func detailText(nameColor: Color) -> AttributedString {
        var text = AttributedString(detail)
        for name in emphasized where !name.isEmpty {
            if let range = text.range(of: name) {
                text[range].foregroundColor = nameColor
            }
        }
        return text
    }
}

// MARK: - Card Shell

/// The near-black card every block sits in, with an optional title and chevron on top.
struct SeuMesCard<Content: View>: View {

    var title: String? = nil
    var showsChevron = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            if let title {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .padding(.spacing(.medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SeuMesPalette.cornerRadius, style: .continuous)
                .fill(SeuMesPalette.card)
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Artwork

/// The picture that goes with a highlight or a top card. Falls back to a gray tile with a
/// symbol when there's no photo or it doesn't load.
struct SeuMesArtwork: View {

    let artwork: MonthlyHighlight.Artwork

    var body: some View {
        switch artwork {
        case .author(let photo):
            remoteImage(photo.flatMap(URL.init(string:)), placeholder: "person.fill")
                .clipShape(Circle())

        case .sound(let authorPhoto):
            remoteImage(authorPhoto.flatMap(URL.init(string:)), placeholder: "waveform")
                .clipShape(.rect(cornerRadius: 4))

        case .episode(let imageURL):
            remoteImage(imageURL, placeholder: "headphones")
                .clipShape(.rect(cornerRadius: 4))

        case .episodes(let imageURLs):
            let columns = [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(imageURLs.prefix(4).enumerated()), id: \.offset) { _, url in
                    remoteImage(url, placeholder: "headphones")
                        .clipShape(.rect(cornerRadius: 4))
                }
            }

        case .symbol(let name):
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.10, blue: 0.42), Color(red: 0.42, green: 0.22, blue: 0.70)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                centeredSymbol(name, fraction: 0.45)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .clipShape(.rect(cornerRadius: 4))
        }
    }

    private func remoteImage(_ url: URL?, placeholder: String) -> some View {
        Color(.tertiarySystemFill)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                centeredSymbol(placeholder, fraction: 0.35)
                    .foregroundStyle(.tertiary)
            }
            .overlay {
                if let url {
                    KFImage(url)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// A symbol a set fraction of the tile's width, so it reads the same in a 48-point row
    /// and a full-width card.
    private func centeredSymbol(_ name: String, fraction: CGFloat) -> some View {
        GeometryReader { proxy in
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: proxy.size.width * fraction, height: proxy.size.width * fraction)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Highlight Card

/// A feed card: the big picture, the headline, the sentence and the week, with its own
/// share button.
struct SeuMesHighlightCard: View {

    let highlight: MonthlyHighlight
    let onShare: () -> Void

    var body: some View {
        SeuMesCard {
            VStack(alignment: .leading, spacing: .spacing(.medium)) {
                SeuMesArtwork(artwork: highlight.artwork)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                    Text(highlight.headline)
                        .font(.title2)
                        .bold()
                        .fixedSize(horizontal: false, vertical: true)

                    Text(highlight.detailText(nameColor: SeuMesPalette.name))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                HStack {
                    Text(highlight.dateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Compartilhar destaque")
                }
            }
        }
    }
}

// MARK: - Drill-Downs

/// The full lists behind the summary's cards.
struct MonthlyStatsDetailView: View {

    enum Kind {
        case virgulas, authors, episodes
    }

    let kind: Kind
    let stats: MonthlyStats

    private var title: String {
        switch kind {
        case .virgulas: "Vírgulas de \(stats.month.name)"
        case .authors: "Autores de \(stats.month.name)"
        case .episodes: "Episódios de \(stats.month.name)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing(.large)) {
                switch kind {
                case .virgulas:
                    if !stats.topSharedSounds.isEmpty {
                        soundSection("Mais Compartilhadas", items: stats.topSharedSounds, unit: ("compartilhamento", "compartilhamentos"))
                    }
                    if !stats.topPlayedSounds.isEmpty {
                        soundSection("Mais Tocadas", items: stats.topPlayedSounds, unit: ("vez", "vezes"))
                    }

                case .authors:
                    rows {
                        ForEach(Array(stats.topAuthors.enumerated()), id: \.element.id) { index, author in
                            row(rank: index + 1, artwork: .author(photo: author.photo), title: author.name, detail: authorDetail(author))
                        }
                    }

                case .episodes:
                    rows {
                        ForEach(Array(stats.topEpisodes.enumerated()), id: \.element.id) { index, episode in
                            row(
                                rank: index + 1,
                                artwork: .episode(imageURL: episode.imageURL),
                                title: episode.title,
                                detail: MonthlyStats.formattedDuration(episode.secondsListened)
                            )
                        }
                    }
                    if stats.episodesFinished > 0 {
                        Text("\(MonthlyStats.counted(stats.episodesFinished, "episódio ouvido", "episódios ouvidos")) até o fim.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, .spacing(.small))
        }
        .background(SeuMesPalette.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func soundSection(_ title: String, items: [TopChartItem], unit: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text(title)
                .font(.title3)
                .bold()
            rows {
                ForEach(items) { item in
                    row(
                        rank: Int(item.rankNumber) ?? 0,
                        artwork: nil,
                        title: item.contentName,
                        detail: "\(item.contentAuthorName) · \(MonthlyStats.counted(item.shareCount, unit.0, unit.1))"
                    )
                }
            }
        }
    }

    private func rows<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: SeuMesPalette.cornerRadius, style: .continuous)
                .fill(SeuMesPalette.card)
        )
    }

    private func row(rank: Int, artwork: MonthlyHighlight.Artwork?, title: String, detail: String) -> some View {
        HStack(spacing: .spacing(.small)) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26)

            if let artwork {
                SeuMesArtwork(artwork: artwork)
                    .frame(width: 48, height: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .lineLimit(2)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, .spacing(.small))
        .padding(.vertical, .spacing(.xSmall))
        .accessibilityElement(children: .combine)
    }

    private func authorDetail(_ author: MonthlyStats.RankedAuthor) -> String {
        var parts: [String] = []
        if author.shareCount > 0 {
            parts.append(MonthlyStats.counted(author.shareCount, "compartilhamento", "compartilhamentos"))
        }
        if author.playCount > 0 {
            parts.append("tocado \(MonthlyStats.counted(author.playCount, "vez", "vezes"))")
        }
        return parts.joined(separator: " · ")
    }
}
