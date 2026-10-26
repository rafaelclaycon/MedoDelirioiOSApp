//
//  PersonalTrendsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// The user's own rankings and episode stats, one tap into Você, with Seu Mês on top.
/// Used to be the "Pessoais" side of Tendências.
struct PersonalTrendsView: View {

    /// The month the Seu Mês card leads to. No card until there's a month to show.
    @State private var featuredMonth: MonthlyStats?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing(.large)) {
                if let featuredMonth {
                    NavigationLink {
                        MonthlyStatsView(initialMonth: featuredMonth.month)
                    } label: {
                        YouCardLabel(
                            systemImage: "calendar",
                            symbolColor: .darkerGreen,
                            title: "Seu Mês: \(featuredMonth.title)",
                            detail: featuredMonth.summary,
                            // Green, to stand out a little from the rankings below.
                            background: .darkerGreen.opacity(0.16),
                            border: .darkerGreen.opacity(0.6)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                MostSharedByMeView()

                Divider()
                    .padding(.horizontal)

                EpisodeStatsView()
            }
            .padding(.top, .spacing(.small))
        }
        .navigationTitle("Suas Tendências")
        .onAppear {
            // Again on coming back, so a month that just ended takes over the card.
            featuredMonth = MonthlyStatsProvider.featured(in: MonthlyStatsProvider().availableMonths())
            Task {
                await AnalyticsService().send(
                    originatingScreen: "PersonalTrendsView",
                    action: "didViewPersonalTrends"
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        PersonalTrendsView()
    }
    .environment(EpisodeListenStore())
    .environment(EpisodeBookmarkStore())
    .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
}
