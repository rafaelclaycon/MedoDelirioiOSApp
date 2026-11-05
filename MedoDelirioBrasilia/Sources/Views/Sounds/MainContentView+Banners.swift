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
        /// Dev Options' switch: shows the banner whatever the server, the year's data or an
        /// earlier dismissal say.
        @AppStorage(FeatureFlag.retrospective.rawValue) private var isRetrospectiveForced = false
        /// What the server last said for this version, kept when a check fails.
        @State private var isRetroAllowedByServer = false
        /// Closed in this session. Remembered for good too, unless it was forced.
        @State private var isRetroBannerClosed = false
        /// Read when Vírgulas appears rather than in the body, since it goes to the database.
        @State private var hasRetroStats = false
        @State private var showRetroStories = false
        /// Offered to people who have never played an episode. Nil hides the card.
        @State private var invitedEpisode: PodcastEpisode?
        private let episodeInvitation = EpisodeInvitation()

        @Environment(\.scenePhase) private var scenePhase
        @Environment(EpisodeHighlightStore.self) private var highlightStore

        var body: some View {
            VStack {
                if showRetroBanner {
                    RetroBanner(
                        year: Self.retroYear,
                        openStoriesAction: {
                            showRetroStories = true
                            sendRetroAnalytics("didOpenRetroFromBanner")
                        },
                        dismissAction: {
                            if !isRetrospectiveForced {
                                AppPersistentMemory.shared.setHasDismissedRetroBanner(year: Self.retroYear, to: true)
                            }
                            withAnimation {
                                isRetroBannerClosed = true
                            }
                            sendRetroAnalytics("didDismissRetroBanner")
                        }
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
                StoriesView(year: Self.retroYear, onShareAnalytics: { analyticsString in
                    // A tap on the share button, not a confirmed share: the sheet can still
                    // be cancelled.
                    sendRetroAnalytics(analyticsString)
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
                    await updateRetroBanner()
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
                    // Turned on on the server while the app sat in the background.
                    Task {
                        await updateRetroBanner()
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

        // MARK: - Retrospectiva

        static let retroYear = 2026

        /// Forced in Dev Options, or the server allows this version, they've never closed it and
        /// the year has something in it to show.
        private var showRetroBanner: Bool {
            guard !isRetroBannerClosed else { return false }
            if isRetrospectiveForced { return true }
            return isRetroAllowedByServer
                && hasRetroStats
                && !AppPersistentMemory.shared.hasDismissedRetroBanner(year: Self.retroYear)
        }

        /// The server's answer is kept when the request fails.
        private func updateRetroBanner() async {
            hasRetroStats = StoriesView.ViewModel.hasSomethingToShow(year: Self.retroYear)
            guard let allowed = await bannerRepository.showRetroBanner() else { return }
            isRetroAllowedByServer = allowed
        }

        private func sendRetroAnalytics(_ action: String) {
            Task {
                await AnalyticsService().send(originatingScreen: "Retro\(Self.retroYear)", action: action)
            }
        }

        // MARK: - Election

        /// Keeps the current state when the request fails.
        private func updateElectionLiveBanner() async {
            guard let info = try? await APIClient.shared.electionLiveInfo() else { return }
            showElectionLiveBanner = ElectionLiveActivityManager.isAvailable(info)
            officialResultsURL = info.officialResults
        }
    }
}
