//
//  MainContentView+Banners.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 13/04/24.
//

import SwiftUI

extension MainContentView {

    struct BannersView: View {

        let bannerRepository: BannerRepositoryProtocol
        @Binding var toast: Toast?

        @State private var dynamicBanner: DynamicBannerData?
        @State private var showElectionLiveBanner: Bool = false
        @State private var officialResultsURL = ElectionLiveInfo.defaultOfficialResultsURL
        @State private var showAnniversaryBanner: Bool = false
        @State private var showDunBanner = !AppPersistentMemory.shared.hasDismissedDunBanner()
        /// Until the Retrospectiva launches, only for whoever turns it on in Dev Options.
        @AppStorage(FeatureFlag.retrospective.rawValue) private var isRetrospectiveEnabled = false
        @State private var showRetroBanner = true
        @State private var showRetroStories = false
        /// Offered to people who have never played an episode. Nil hides the card.
        @State private var invitedEpisode: PodcastEpisode?
        private let episodeInvitation = EpisodeInvitation()

        @Environment(\.scenePhase) private var scenePhase
        @Environment(EpisodeHighlightStore.self) private var highlightStore

        var body: some View {
            VStack {
                if isRetrospectiveEnabled, showRetroBanner {
                    RetroBanner(
                        openStoriesAction: { showRetroStories = true },
                        dismissAction: { showRetroBanner = false }
                    )
                    .padding(.top, .spacing(.xxxSmall))
                    .padding(.bottom, .spacing(.xSmall))
                }

                if showElectionLiveBanner {
                    ElectionLiveBannerView(toast: $toast, officialResultsURL: officialResultsURL)
                        .padding(.top, .spacing(.xxxSmall))
                        .padding(.bottom, .spacing(.xSmall))
                }

                if showAnniversaryBanner {
                    AnniversaryBannerView()
                        .padding(.top, .spacing(.xxxSmall))
                        .padding(.bottom, .spacing(.xSmall))
                }

                if let invitedEpisode {
                    EpisodeInvitationCard(
                        episode: invitedEpisode,
                        title: "Ouça o podcast aqui no app",
                        caption: highlightStore.highlight(for: invitedEpisode.id)?.label,
                        originatingScreen: "VirgulasEpisodeInvitation",
                        onDismiss: {
                            episodeInvitation.dismissCard()
                            withAnimation {
                                self.invitedEpisode = nil
                            }
                        }
                    )
                    .padding(.top, .spacing(.xxxSmall))
                    .padding(.bottom, .spacing(.xSmall))
                }

                TranscriptDownloadBannerView()
                    .padding(.top, .spacing(.xxxSmall))
                    .padding(.bottom, .spacing(.xSmall))

                if showDunBanner {
                    DunBannerView(isBeingShown: $showDunBanner)
                        .padding(.top, .spacing(.xxxSmall))
                        .padding(.bottom, .spacing(.xSmall))
                }

                // Read in the body, so the banner follows the gate when it reopens or closes.
                if DonationGate.shared.isAllowed, let dynamicBanner {
                    DynamicBanner(
                        bannerData: dynamicBanner,
                        textCopyFeedback: { message in
                            self.toast = Toast(message: message, type: .thankYou)
                        }
                    )
                    .padding(.top, .spacing(.xxxSmall))
                    .padding(.bottom, .spacing(.xSmall))
                }
            }
            .fullScreenCover(isPresented: $showRetroStories) {
                StoriesView(onShareAnalytics: { analyticsString in
                    // A tap on the share button, not a confirmed share: the sheet can still
                    // be cancelled.
                    Task {
                        await AnalyticsService().send(originatingScreen: "Retro2026", action: analyticsString)
                    }
                })
            }
            .onAppear {
                Task{
                    dynamicBanner = await bannerRepository.dynamicBanner()
                }
                Task{
                    showAnniversaryBanner = await bannerRepository.showAnniversaryBanner()
                }
                Task{
                    await updateElectionLiveBanner()
                }
                Task {
                    // Only Episodes loads it otherwise, and these people haven't been there.
                    await highlightStore.loadIfNeeded()
                    updateEpisodeInvitation()
                }
            }
            // The server switches the election banner on during election day, often while
            // the app sits in the background, so check again whenever it comes back.
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        await updateElectionLiveBanner()
                    }
                    updateEpisodeInvitation()
                }
            }
        }

        /// Checked on every appearance, so the card goes away once they've listened from it
        /// and come back, or from anywhere else.
        private func updateEpisodeInvitation() {
            guard episodeInvitation.canShowCard(), episodeInvitation.hasNeverListened() else {
                invitedEpisode = nil
                return
            }
            invitedEpisode = episodeInvitation.suggestedEpisode(highlightedEpisodeId: highlightStore.highlight?.episodeId)
            if invitedEpisode != nil {
                episodeInvitation.cardWasShown()
            }
        }

        /// Keeps the current state when the request fails.
        private func updateElectionLiveBanner() async {
            guard let info = try? await APIClient.shared.electionLiveInfo() else { return }
            showElectionLiveBanner = ElectionLiveActivityManager.isAvailable(info)
            officialResultsURL = info.officialResults
        }
    }
}
