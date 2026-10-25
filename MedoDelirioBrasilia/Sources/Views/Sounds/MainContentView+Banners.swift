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

        @Environment(\.scenePhase) private var scenePhase

        var body: some View {
            VStack {
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
            }
            // The server switches the election banner on during election day, often while
            // the app sits in the background, so check again whenever it comes back.
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    Task {
                        await updateElectionLiveBanner()
                    }
                }
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
