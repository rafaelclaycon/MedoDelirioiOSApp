//
//  PersonalTrendsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// The user's own rankings and episode stats, one tap into Você. Used to be the
/// "Pessoais" side of Tendências.
struct PersonalTrendsView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing(.large)) {
                MostSharedByMeView()

                Divider()
                    .padding(.horizontal)

                EpisodeStatsView()
            }
            .padding(.top, .spacing(.small))
        }
        .navigationTitle("Suas Tendências")
        .onAppear {
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
}
