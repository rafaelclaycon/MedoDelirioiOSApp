//
//  MonthlyStatsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/10/26.
//

import SwiftUI
import Kingfisher

/// Seu Mês: what someone did in the app in a month, one month at a time, with a picture
/// of it to share. The year-end Retrospectiva is the big version of this.
struct MonthlyStatsView: View {

    /// The month to open on. The last one with data when it isn't there.
    let initialMonth: StatsMonth?

    @Environment(ProfileStore.self) private var profileStore

    @State private var months: [MonthlyStats] = []
    @State private var selectedMonth: StatsMonth?
    @State private var hasLoaded = false
    @State private var shareSnapshot: MonthlyStatsShareSnapshot?

    private let cardColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var selectedStats: MonthlyStats? {
        months.first { $0.month == selectedMonth }
    }

    var body: some View {
        ScrollView {
            if let stats = selectedStats {
                VStack(alignment: .leading, spacing: .spacing(.large)) {
                    monthPicker
                    header(stats)
                    statCards(stats)

                    if !stats.topSharedSounds.isEmpty {
                        ranking(title: "Mais Compartilhadas", items: stats.topSharedSounds)
                    }

                    if !stats.topPlayedSounds.isEmpty {
                        ranking(title: "Mais Tocadas", items: stats.topPlayedSounds)
                    }

                    if let author = stats.topAuthor {
                        topAuthor(author)
                    }

                    if let episode = stats.topEpisode {
                        topEpisode(episode, finished: stats.episodesFinished)
                    }

                    shareButton(stats)
                }
                .padding(.top, .spacing(.small))
                .padding(.bottom, .spacing(.large))
            } else if hasLoaded {
                ContentUnavailableView(
                    "Nada Por Aqui Ainda",
                    systemImage: "calendar",
                    description: Text("Compartilhe Vírgulas e ouça episódios para ver o resumo do seu mês.")
                )
                .padding(.top, .spacing(.xLarge))
            }
        }
        .navigationTitle("Seu Mês")
        .toolbar {
            if let stats = selectedStats {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        share(stats)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Compartilhar")
                }
            }
        }
        .sheet(item: $shareSnapshot) { snapshot in
            MonthlyStatsShareView(snapshot: snapshot)
        }
        .onAppear {
            load()
        }
        .onChange(of: selectedMonth) {
            sendViewAnalytics()
        }
    }

    // MARK: - Subviews

    private var monthPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacing(.xSmall)) {
                    ForEach(months) { stats in
                        let isSelected = stats.month == selectedMonth
                        Button {
                            withAnimation(.snappy) {
                                selectedMonth = stats.month
                            }
                        } label: {
                            Text(stats.month.name)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, .spacing(.small))
                                .padding(.vertical, .spacing(.xxSmall))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .background(
                                    Capsule().fill(isSelected ? Color.darkerGreen : Color.gray.opacity(0.15))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .id(stats.month)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .trailing)
            }
            .onChange(of: selectedMonth) {
                withAnimation(.snappy) {
                    proxy.scrollTo(selectedMonth, anchor: .center)
                }
            }
        }
    }

    private func header(_ stats: MonthlyStats) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
            Text(verbatim: "\(stats.month.name) de \(stats.month.year)")
                .font(.largeTitle)
                .bold()

            if stats.isInProgress {
                Text("Até agora. O mês ainda não acabou.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private func statCards(_ stats: MonthlyStats) -> some View {
        LazyVGrid(columns: cardColumns, spacing: .spacing(.small)) {
            if stats.shareCount > 0 {
                EpisodeStatsView.StatCard(
                    value: MonthlyStats.formattedNumber(stats.shareCount),
                    label: stats.shareCount == 1 ? "Compartilhamento" : "Compartilhamentos",
                    systemImage: "square.and.arrow.up"
                )
            }

            if stats.playCount > 0 {
                EpisodeStatsView.StatCard(
                    value: MonthlyStats.formattedNumber(stats.playCount),
                    label: stats.playCount == 1 ? "Vírgula Tocada" : "Vírgulas Tocadas",
                    systemImage: "play.fill"
                )
            }

            if stats.hasEpisodes {
                EpisodeStatsView.StatCard(
                    value: stats.formattedListeningTime,
                    label: "De Episódios",
                    systemImage: "headphones"
                )
            }

            EpisodeStatsView.StatCard(
                value: "\(stats.activeDays)",
                label: stats.activeDays == 1 ? "Dia no App" : "Dias no App",
                systemImage: "calendar"
            )
        }
        .padding(.horizontal, 14)
    }

    private func ranking(title: String, items: [TopChartItem]) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                ForEach(items) { item in
                    TopChartRow(item: item)
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func topAuthor(_ author: TopAuthorItem) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("Autor do Mês")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: .spacing(.small)) {
                KFImage(URL(string: author.authorPhoto ?? ""))
                    .placeholder {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.2))
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(author.authorName)
                        .font(.subheadline)
                        .bold()
                        .lineLimit(2)

                    Text(MonthlyStats.counted(author.shareCount, "compartilhamento", "compartilhamentos"))
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
            .accessibilityElement(children: .combine)
            .padding(.horizontal, 14)
        }
    }

    private func topEpisode(_ episode: MonthlyStats.TopEpisode, finished: Int) -> some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            Text("Episódio do Mês")
                .font(.headline)
                .padding(.horizontal)

            EpisodeStatsView.EpisodeRankRow(
                rank: 1,
                title: episode.title,
                duration: MonthlyStats.formattedDuration(episode.secondsListened)
            )
            .padding(.horizontal, 14)

            if finished > 0 {
                Text("\(MonthlyStats.counted(finished, "episódio ouvido", "episódios ouvidos")) até o fim.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
    }

    private func shareButton(_ stats: MonthlyStats) -> some View {
        Button {
            share(stats)
        } label: {
            Label("Compartilhar Meu Mês", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .spacing(.xxSmall))
        }
        .buttonStyle(.glassProminent)
        .tint(.darkerGreen)
        .padding(.horizontal)
    }

    // MARK: - Functions

    private func load() {
        months = MonthlyStatsProvider().availableMonths()
        hasLoaded = true
        // Keeps the month picked before leaving and coming back, if it's still there.
        if let selectedMonth, months.contains(where: { $0.month == selectedMonth }) {
            return
        }
        selectedMonth = months.first { $0.month == initialMonth }?.month ?? months.last?.month
    }

    private func share(_ stats: MonthlyStats) {
        shareSnapshot = MonthlyStatsShareSnapshot(stats: stats, profile: profileStore)
    }

    private func sendViewAnalytics() {
        guard let selectedMonth else { return }
        Task {
            await AnalyticsService().send(
                originatingScreen: "MonthlyStatsView",
                action: "didViewMonthlyStats(\(selectedMonth.id))"
            )
        }
    }
}

#Preview {
    NavigationStack {
        MonthlyStatsView(initialMonth: nil)
    }
    .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
}
