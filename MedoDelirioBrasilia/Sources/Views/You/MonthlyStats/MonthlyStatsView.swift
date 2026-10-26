//
//  MonthlyStatsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/10/26.
//

import SwiftUI

/// Seu Mês: what someone did in the app, month by month, newest on top, in the style of
/// Spotify's Sound Capsule. Each month has a summary, the highlights of its weeks and a
/// picture of it to share. The year-end Retrospectiva is the big version of this.
struct MonthlyStatsView: View {

    /// The month to scroll to when the page opens.
    let initialMonth: StatsMonth?

    @Environment(ProfileStore.self) private var profileStore

    /// Newest first.
    @State private var months: [MonthlyStats] = []
    @State private var hasLoaded = false
    @State private var shareSnapshot: MonthlyStatsShareSnapshot?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if months.isEmpty {
                    if hasLoaded {
                        ContentUnavailableView(
                            "Nada Por Aqui Ainda",
                            systemImage: "calendar",
                            description: Text("Compartilhe Vírgulas e ouça episódios para ver o resumo do seu mês.")
                        )
                        .padding(.top, .spacing(.xLarge))
                    }
                } else {
                    LazyVStack(alignment: .leading, spacing: .spacing(.xLarge) * 2) {
                        ForEach(months) { stats in
                            MonthSection(
                                stats: stats,
                                onShareMonth: { share(.month(stats)) },
                                onShareHighlight: { share(.highlight($0)) }
                            )
                            .id(stats.month)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, .spacing(.small))
                }
            }
            .onChange(of: hasLoaded) {
                guard let initialMonth, initialMonth != months.first?.month else { return }
                // A tick later, once the stack has laid out the months.
                Task { @MainActor in
                    proxy.scrollTo(initialMonth, anchor: .top)
                }
            }
        }
        .background(SeuMesPalette.background)
        .navigationTitle("Seu Mês")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareSnapshot) { snapshot in
            MonthlyStatsShareView(snapshot: snapshot)
        }
        .onAppear {
            load()
        }
    }

    // MARK: - Functions

    private func load() {
        months = MonthlyStatsProvider().availableMonths().reversed()
        guard !hasLoaded else { return }
        hasLoaded = true
        Task {
            await AnalyticsService().send(
                originatingScreen: "MonthlyStatsView",
                action: "didViewMonthlyStats(\(initialMonth?.id ?? "none"))"
            )
        }
    }

    private func share(_ content: MonthlyShareContent) {
        shareSnapshot = MonthlyStatsShareSnapshot(content: content, profile: profileStore)
    }
}

// MARK: - Month Section

extension MonthlyStatsView {

    /// One month: its header, the summary cards and the week-by-week highlights.
    struct MonthSection: View {

        let stats: MonthlyStats
        let onShareMonth: () -> Void
        let onShareHighlight: (MonthlyHighlight) -> Void

        @State private var isShowingInfo = false

        var body: some View {
            VStack(alignment: .leading, spacing: .spacing(.small)) {
                header
                summary

                ForEach(stats.highlights) { highlight in
                    SeuMesHighlightCard(highlight: highlight) {
                        onShareHighlight(highlight)
                    }
                }
            }
        }

        // MARK: Header

        private var header: some View {
            VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                HStack(spacing: .spacing(.xSmall)) {
                    Text("\(stats.month.name) \(Text(verbatim: String(stats.month.year)).foregroundStyle(.secondary))")
                        .font(.title)
                        .bold()

                    Button {
                        isShowingInfo = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sobre o Seu Mês")

                    Spacer()

                    Button(action: onShareMonth) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .frame(width: 44, height: 44, alignment: .trailing)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Compartilhar \(stats.month.name)")
                }

                if stats.isInProgress {
                    Text("Até agora. O mês ainda não acabou.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, .spacing(.xxSmall))
            .alert("Sobre o Seu Mês", isPresented: $isShowingInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Um resumo do que você fez no app no mês: Vírgulas compartilhadas e tocadas e episódios ouvidos. Tudo é calculado no seu aparelho, nada vem do servidor. As Vírgulas tocadas contam a partir de outubro de 2026.")
            }
        }

        // MARK: Summary

        /// The time card on top, author and episode side by side, then the Vírgulas. A month
        /// without episodes leads with the Vírgulas instead, and a missing half card leaves
        /// the other one the whole row.
        @ViewBuilder
        private var summary: some View {
            if stats.hasEpisodes {
                episodesTimeCard
            } else {
                virgulasCard
            }

            let halves = halfCards
            if !halves.isEmpty {
                HStack(alignment: .top, spacing: .spacing(.small)) {
                    ForEach(halves, id: \.self) { half in
                        halfCard(half)
                    }
                }
            }

            if stats.hasEpisodes && stats.hasVirgulas {
                virgulasCard
            }
        }

        private var episodesTimeCard: some View {
            NavigationLink {
                MonthlyStatsDetailView(kind: .episodes, stats: stats)
            } label: {
                SeuMesCard(title: "Episódios ouvidos", showsChevron: true) {
                    Text(MonthlyStats.counted(stats.minutesListened, "minuto", "minutos"))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(SeuMesPalette.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .buttonStyle(.plain)
        }

        private var virgulasCard: some View {
            NavigationLink {
                MonthlyStatsDetailView(kind: .virgulas, stats: stats)
            } label: {
                SeuMesCard(title: stats.shareCount > 0 ? "Vírgulas compartilhadas" : "Vírgulas tocadas", showsChevron: true) {
                    VStack(alignment: .leading, spacing: .spacing(.xxxSmall)) {
                        Text(MonthlyStats.formattedNumber(stats.shareCount > 0 ? stats.shareCount : stats.playCount))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(SeuMesPalette.green)

                        if stats.shareCount > 0, stats.playCount > 0 {
                            Text("e \(MonthlyStats.counted(stats.playCount, "tocada", "tocadas"))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }

        private enum Half: Hashable {
            case author, episode, sound
        }

        /// Author and episode, like Spotify's artist and song. A month without episodes
        /// shows its top Vírgula in the episode's place.
        private var halfCards: [Half] {
            var halves: [Half] = []
            if stats.topAuthor != nil {
                halves.append(.author)
            }
            if stats.topEpisode != nil {
                halves.append(.episode)
            } else if !(stats.topSharedSounds.isEmpty && stats.topPlayedSounds.isEmpty) {
                halves.append(.sound)
            }
            return halves
        }

        @ViewBuilder
        private func halfCard(_ half: Half) -> some View {
            switch half {
            case .author:
                if let author = stats.topAuthor {
                    NavigationLink {
                        MonthlyStatsDetailView(kind: .authors, stats: stats)
                    } label: {
                        topCard(title: "Autor do mês", name: author.name, color: SeuMesPalette.blue, artwork: .author(photo: author.photo))
                    }
                    .buttonStyle(.plain)
                }

            case .episode:
                if let episode = stats.topEpisode {
                    NavigationLink {
                        MonthlyStatsDetailView(kind: .episodes, stats: stats)
                    } label: {
                        topCard(title: "Episódio do mês", name: episode.title, color: SeuMesPalette.yellow, artwork: .episode(imageURL: episode.imageURL))
                    }
                    .buttonStyle(.plain)
                }

            case .sound:
                if let sound = stats.topSharedSounds.first ?? stats.topPlayedSounds.first {
                    NavigationLink {
                        MonthlyStatsDetailView(kind: .virgulas, stats: stats)
                    } label: {
                        topCard(
                            title: "Vírgula do mês",
                            name: sound.contentName,
                            color: SeuMesPalette.yellow,
                            artwork: .sound(authorPhoto: stats.topAuthors.first { $0.id == sound.contentAuthorId }?.photo)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        private func topCard(title: String, name: String, color: Color, artwork: MonthlyHighlight.Artwork) -> some View {
            SeuMesCard(title: title, showsChevron: true) {
                VStack(alignment: .leading, spacing: .spacing(.small)) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(color)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)

                    SeuMesArtwork(artwork: artwork)
                        .frame(width: 120, height: 120)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MonthlyStatsView(initialMonth: nil)
    }
    .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
}
