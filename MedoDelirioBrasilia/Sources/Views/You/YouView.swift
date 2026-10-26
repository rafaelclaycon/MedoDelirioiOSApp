//
//  YouView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// The Você tab: the user, their numbers, their own rankings and how their devices
/// keep in step. No account; the profile lives in iCloud.
struct YouView: View {

    let openSettingsAction: () -> Void

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.usesSidebarLayout) private var usesSidebarLayout

    @State private var isEditingProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacing(.large)) {
                Button {
                    isEditingProfile = true
                } label: {
                    YouHeaderView()
                }
                .buttonStyle(.plain)

                YouNumbersView()

                YouGamesSection()

                VStack(spacing: .spacing(.small)) {
                    NavigationLink {
                        PersonalTrendsView()
                    } label: {
                        YouCardLabel(
                            systemImage: "chart.line.uptrend.xyaxis",
                            title: "Suas Tendências",
                            detail: "O resumo do seu mês, suas vírgulas mais compartilhadas e seus números nos episódios."
                        )
                    }
                    .buttonStyle(.plain)

                    YouSyncCardView()
                }
                .padding(.horizontal)
            }
            .padding(.bottom, .spacing(.large))
        }
        // The hero's green runs up under the status bar, so the bar's own fade would
        // only muddy it.
        .scrollEdgeEffectHidden(true, for: .top)
        .navigationTitle("Você")
        // The hero already says who this is; a title over it would compete with the name.
        // Inline first: removing the title alone leaves the large title's space behind.
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar {
            // Same corner as the gear in Vírgulas (`LeadingToolbarControls`), and hidden
            // the same way in the sidebar layout, whose footer already has Configurações.
            if !usesSidebarLayout {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        openSettingsAction()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Configurações")
                }
            }
        }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditView()
        }
        .onAppear {
            // Shares and listens since launch can move the date back on a new install.
            profileStore.foldInEarliestActivity()

            Task {
                await AnalyticsService().send(
                    originatingScreen: "YouView",
                    action: "didViewYouTab"
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        YouView(openSettingsAction: {})
    }
    .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
    .environment(EpisodePlayedStore(database: FakeLocalDatabase()))
    .environment(EpisodeListenStore())
    .environment(EpisodeBookmarkStore())
}
