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
        @State private var showAnniversaryBanner: Bool = false
        @State private var showDunBanner = !AppPersistentMemory.shared.hasDismissedDunBanner()

        var body: some View {
            VStack {
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

                if let dynamicBanner {
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
            }
        }
    }
}
