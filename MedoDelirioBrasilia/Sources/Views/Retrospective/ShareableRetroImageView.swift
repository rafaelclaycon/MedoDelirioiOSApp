//
//  ShareableRetroImageView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/25.
//

import SwiftUI

/// The year's colors, for the stories and the share picture. 2026 is red, for Lula's win,
/// in the reds of the election night's celebration. 2025 was yellow and green.
enum RetroPalette {

    static let red = Color(red: 0.86, green: 0.09, blue: 0.12)
    static let deepRed = Color(red: 0.55, green: 0.03, blue: 0.06)
    static let wine = Color(red: 0.32, green: 0.02, blue: 0.05)
    /// Light pages and highlights on the dark ones.
    static let cream = Color(red: 1.0, green: 0.94, blue: 0.88)
    /// Big numbers on the darkest reds, where the bright red would sink.
    static let coral = Color(red: 1.0, green: 0.56, blue: 0.50)

    static let shareTop = Color(red: 0.90, green: 0.11, blue: 0.14)
    static let shareBottom = Color(red: 0.45, green: 0.02, blue: 0.06)
    static let hashtag = coral.opacity(0.55)
    static let ink = Color.white
    static let value = cream
}

/// A picture of someone's year to share, at 828 × 1472: the author they shared most, their
/// top Vírgulas, the totals, and the hours and the episode they spent the most time with.
/// Same look as 2025's, drawn here rather than over a template image, so the year and the
/// rows can change.
struct ShareableRetroImageView: View {

    let year: Int
    let authorPhoto: UIImage?
    let authorName: String?
    let topSounds: [TopChartItem]
    let totalShares: Int
    let favoriteDay: String
    /// Zero leaves the episodes row out.
    var secondsListened: Double = 0
    var topEpisodeTitle: String? = nil

    private let width: CGFloat = 828
    private let height: CGFloat = 1472
    private let margin: CGFloat = 62

    private var hasEpisodes: Bool { secondsListened >= 60 }

    /// Shorter with episodes, to make room for their row.
    private var photoHeight: CGFloat { hasEpisodes ? 380 : 470 }

    /// "42 horas", or "3h 20min" under ten hours.
    private var listeningText: String {
        let hours = secondsListened / 3600
        return hours >= 10 ? "\(Int(hours)) horas" : MonthlyStats.formattedDuration(secondsListened)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [RetroPalette.shareTop, RetroPalette.shareBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Over the photo's bottom edge, as in 2025.
            hashtag
                .frame(width: width - 26, alignment: .trailing)
                .offset(y: 52 + photoHeight - 60)

            VStack(alignment: .leading, spacing: 0) {
                authorPhotoView

                Text(authorName ?? " ")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(RetroPalette.cream)
                    .lineLimit(1)
                    .padding(.top, 12)

                // Keeps the list clear of the hashtag.
                Spacer(minLength: 110)

                if !topSounds.isEmpty {
                    label("Sons mais compartilhados")
                    soundsList
                        .padding(.top, 14)
                }

                statsRow(
                    left: ("Total de\ncompartilhamentos", MonthlyStats.formattedNumber(totalShares), 64),
                    right: ("Dia favorito", favoriteDay, 44)
                )
                .padding(.top, 34)

                if hasEpisodes {
                    episodesRow
                        .padding(.top, 28)
                }

                Spacer(minLength: 0)

                footer
            }
            .padding(.horizontal, margin)
            .padding(.top, 52)
            .padding(.bottom, 40)
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .frame(width: width, height: height)
    }

    // MARK: - Subviews

    private var hashtag: some View {
        VStack(alignment: .trailing, spacing: -18) {
            Text("#MedoE")
            Text("DelírioiOS")
        }
        .font(.system(size: 108, weight: .bold))
        .foregroundStyle(RetroPalette.hashtag)
    }

    private var authorPhotoView: some View {
        Group {
            if let photo = authorPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
            }
        }
        .frame(width: 500, height: photoHeight)
        .clipped()
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .regular))
            .foregroundStyle(RetroPalette.ink.opacity(0.85))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Five rows without episodes, four when their row takes the space.
    private var soundsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(topSounds.prefix(hasEpisodes ? 4 : 5).enumerated()), id: \.offset) { index, sound in
                Text("\(index + 1) \(sound.contentName)")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(RetroPalette.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private func statsRow(left: (String, String, CGFloat), right: (String, String, CGFloat)) -> some View {
        HStack(alignment: .top, spacing: 24) {
            stat(label: left.0, value: left.1, size: left.2)
                .frame(width: 340, alignment: .leading)
            stat(label: right.0, value: right.1, size: right.2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Hours on the left; on the right, the episode they spent the most time with, in two
    /// lines at most.
    private var episodesRow: some View {
        HStack(alignment: .top, spacing: 24) {
            stat(label: "Horas de\nepisódios", value: listeningText, size: 56)
                .frame(width: 340, alignment: .leading)

            if let topEpisodeTitle {
                VStack(alignment: .leading, spacing: 8) {
                    label("Episódio mais\nouvido")
                    Text(topEpisodeTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(RetroPalette.value)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func stat(label: String, value: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            self.label(label)
                .font(.system(size: 26))
            Text(value)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(RetroPalette.value)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            Image("podcast_logo")
                .resizable()
                .scaledToFit()
                .frame(height: 104)
                .padding(.leading, -24)

            Spacer(minLength: 0)

            Text("Retrospectiva \(String(year))")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(RetroPalette.ink.opacity(0.9))
                .padding(.bottom, 8)
        }
    }
}

// MARK: - Image Generation

extension ShareableRetroImageView {

    /// Generates a UIImage from this view for sharing
    @MainActor
    func generateImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

// MARK: - Preview

private let previewSounds = [
    TopChartItem(id: "1", rankNumber: "1", contentId: "s1", contentName: "Uma Vírgula de exemplo", contentAuthorId: "a1", contentAuthorName: "Autor", shareCount: 20),
    TopChartItem(id: "2", rankNumber: "2", contentId: "s2", contentName: "Outra Vírgula", contentAuthorId: "a1", contentAuthorName: "Autor", shareCount: 15),
    TopChartItem(id: "3", rankNumber: "3", contentId: "s3", contentName: "Mais uma", contentAuthorId: "a1", contentAuthorName: "Autor", shareCount: 12),
    TopChartItem(id: "4", rankNumber: "4", contentId: "s4", contentName: "A quarta", contentAuthorId: "a1", contentAuthorName: "Autor", shareCount: 10),
    TopChartItem(id: "5", rankNumber: "5", contentId: "s5", contentName: "Uma Vírgula com um título comprido para cortar", contentAuthorId: "a1", contentAuthorName: "Autor", shareCount: 8)
]

#Preview("With episodes") {
    ScrollView {
        ShareableRetroImageView(
            year: 2026,
            authorPhoto: nil,
            authorName: "Autor de Exemplo",
            topSounds: previewSounds,
            totalShares: 1247,
            favoriteDay: "Terça-feira",
            secondsListened: 150_000,
            topEpisodeTitle: "Um episódio de exemplo com um título comprido"
        )
        .scaleEffect(0.4)
        .frame(width: 828 * 0.4, height: 1472 * 0.4)
    }
}

#Preview("Vírgulas only") {
    ScrollView {
        ShareableRetroImageView(
            year: 2026,
            authorPhoto: nil,
            authorName: "Autor de Exemplo",
            topSounds: previewSounds,
            totalShares: 68,
            favoriteDay: "Sexta-feira"
        )
        .scaleEffect(0.4)
        .frame(width: 828 * 0.4, height: 1472 * 0.4)
    }
}
