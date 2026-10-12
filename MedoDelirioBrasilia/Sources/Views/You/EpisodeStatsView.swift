//
//  EpisodeStatsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 17/02/26.
//

import SwiftUI

struct EpisodeStatsView: View {

    @State private var viewModel = ViewModel()

    @Environment(EpisodeListenStore.self) private var listenStore
    @Environment(EpisodeBookmarkStore.self) private var bookmarkStore

    private let cardColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: .spacing(.large)) {
            sectionHeader

            if viewModel.hasData {
                statCardsSection
                topEpisodesSection
            } else {
                noDataView
            }
        }
        .onAppear {
            viewModel.load(
                listenStore: listenStore,
                bookmarkStore: bookmarkStore
            )
        }
    }

    // MARK: - Subviews

    private var sectionHeader: some View {
        HStack {
            Text("Episódios")
                .font(.title2)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var statCardsSection: some View {
        LazyVGrid(columns: cardColumns, spacing: .spacing(.small)) {
            StatCard(
                value: viewModel.formattedHours,
                label: "Horas Ouvidas",
                systemImage: "headphones"
            )

            StatCard(
                value: viewModel.mostCommonDay ?? "—",
                label: "Dia Mais Frequente",
                systemImage: "calendar"
            )

            StatCard(
                value: "\(viewModel.currentStreak)",
                label: "Sequência Atual",
                systemImage: "flame.fill"
            )

            StatCard(
                value: "\(viewModel.longestStreak)",
                label: "Maior Sequência",
                systemImage: "trophy.fill"
            )

            StatCard(
                value: "\(viewModel.bookmarkStreak)",
                label: "Sequência de Marcadores",
                systemImage: "bookmark.fill"
            )
        }
        .padding(.horizontal, 14)
    }

    private var topEpisodesSection: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("Mais Ouvidos")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible())], spacing: .spacing(.xSmall)) {
                ForEach(Array(viewModel.topEpisodes.enumerated()), id: \.element.id) { index, item in
                    EpisodeRankRow(
                        rank: index + 1,
                        title: item.title,
                        duration: item.formattedDuration
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, .spacing(.large))
    }

    private var noDataView: some View {
        VStack(spacing: .spacing(.large)) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Nenhum Dado")
                .font(.title2)
                .bold()

            Text("Ouça episódios do podcast para ver suas estatísticas pessoais.")
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - ViewModel

extension EpisodeStatsView {

    @MainActor
    @Observable
    final class ViewModel {

        private(set) var hasData = false
        private(set) var formattedHours = "0"
        private(set) var mostCommonDay: String?
        private(set) var currentStreak = 0
        private(set) var longestStreak = 0
        private(set) var bookmarkStreak = 0
        private(set) var topEpisodes: [RankedEpisode] = []

        struct RankedEpisode: Identifiable {
            let episodeId: String
            let title: String
            let totalSeconds: Double

            var id: String { episodeId }

            var formattedDuration: String {
                let hours = Int(totalSeconds) / 3600
                let minutes = (Int(totalSeconds) % 3600) / 60
                if hours > 0 {
                    return "\(hours)h \(minutes)min"
                }
                return "\(minutes) min"
            }
        }

        func load(
            listenStore: EpisodeListenStore,
            bookmarkStore: EpisodeBookmarkStore
        ) {
            let logs = listenStore.allLogs()
            guard !logs.isEmpty else {
                hasData = false
                return
            }

            hasData = true

            let totalHours = EpisodeListenStats.totalHoursListened(from: logs)
            if totalHours < 10 {
                formattedHours = String(format: "%.1f", totalHours)
            } else {
                formattedHours = "\(Int(totalHours))"
            }

            let listenDates = listenStore.allListenDates()
            mostCommonDay = EpisodeListenStats.mostCommonListenDay(from: listenDates)
            currentStreak = EpisodeListenStats.currentStreak(from: listenDates)
            longestStreak = EpisodeListenStats.longestStreak(from: listenDates)

            let bookmarkDates = bookmarkStore.allBookmarkDates()
            bookmarkStreak = EpisodeListenStats.bookmarkStreak(from: bookmarkDates)

            let episodes = (try? LocalDatabase.shared.allPodcastEpisodes()) ?? []
            let episodeMap = Dictionary(uniqueKeysWithValues: episodes.map { ($0.id, $0.title) })

            let topByTime = EpisodeListenStats.mostListenedEpisodes(from: logs, limit: 5)
            topEpisodes = topByTime.map { item in
                RankedEpisode(
                    episodeId: item.episodeId,
                    title: episodeMap[item.episodeId] ?? "Episódio desconhecido",
                    totalSeconds: item.totalSeconds
                )
            }
        }
    }
}

// MARK: - Stat Card

extension EpisodeStatsView {

    struct StatCard: View {

        let value: String
        let label: String
        let systemImage: String

        var body: some View {
            cardContent
                .glassEffect(
                    .regular.tint(Color.green.opacity(0.3)).interactive(),
                    in: .rect(cornerRadius: .spacing(.medium))
                )
                .scrollClipDisabled()
        }

        private var cardContent: some View {
            VStack(spacing: .spacing(.xxSmall)) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.green)

                Text(value)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spacing(.small))
            .padding(.horizontal, .spacing(.xSmall))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)")
        }
    }
}

// MARK: - Episode Rank Row

extension EpisodeStatsView {

    struct EpisodeRankRow: View {

        let rank: Int
        let title: String
        let duration: String

        var body: some View {
            HStack(spacing: .spacing(.small)) {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(2)

                    Text(duration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, .spacing(.xSmall))
            .padding(.horizontal, .spacing(.small))
            .background {
                RoundedRectangle(cornerRadius: .spacing(.small))
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        EpisodeStatsView()
    }
    .environment(EpisodeListenStore())
    .environment(EpisodeBookmarkStore())
}
