//
//  TrendsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/05/22.
//

import SwiftUI

/// The audience's rankings. The user's own moved to the Você tab.
struct TrendsView: View {

    @State public var audienceViewModel: MostSharedByAudienceView.ViewModel
    @State private var toast: Toast?

    @Binding var tabSelection: PhoneTab
    @Binding var activePadScreen: PadScreen?

    @Environment(TrendsHelper.self) private var trendsHelper

    // Alert
    @State private var showAlert = false
    @State private var alertTitle = ""

    // MARK: - Computed Properties

    private var showTrends: Bool {
        UserSettings().getEnableTrends()
    }

    private var showSoundsMostSharedByTheAudience: Bool {
        UserSettings().getEnableSoundsMostSharedByTheAudience()
    }

    // MARK: - View Body

    var body: some View {
        VStack {
            if showTrends {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if showSoundsMostSharedByTheAudience {
                            MostSharedByAudienceView(
                                viewModel: audienceViewModel,
                                tabSelection: $tabSelection,
                                activePadScreen: $activePadScreen
                            )
                            .environment(trendsHelper)
                        }
                    }
                }
                .refreshable {
                    await audienceViewModel.onPullToRefreshLists()
                }
            } else {
                TrendsDisabledView()
                    .padding(.horizontal, 25)
            }
        }
        .navigationTitle("Tendências")
        .navigationBarTitleDisplayMode(showTrends ? .large : .inline)
        .onAppear {
            audienceViewModel.displayToast = { message in
                self.toast = Toast(message: message, type: .wait)
            }

            Task {
                await AnalyticsService().send(
                    originatingScreen: "TrendsView",
                    action: "didViewTrendsTab"
                )
            }
        }
        .toast($toast)
        // TODO: Floating selector for Period (Last X Days, etc) and Data Type (Sounds, Songs, Reactions, Episodes).
//        .safeAreaInset(edge: .bottom) {
//            HStack {
//                GlassButton(title: "Tipo", color: .green, fullWidth: true) {
//                    print("Tapped")
//                }
//
//                GlassButton(title: "Data", color: .green) {
//                    print("Tapped")
//                }
//            }
//            .padding(.all, .spacing(.xSmall))
//        }
    }
}

// MARK: - Preview

#Preview {
    TrendsView(
        audienceViewModel: MostSharedByAudienceView.ViewModel(
            trendsService: TrendsService(
                database: FakeLocalDatabase(),
                apiClient: FakeAPIClient(),
                contentRepository: FakeContentRepository()
            )
        ),
        tabSelection: .constant(.episodes),
        activePadScreen: .constant(.trends)
    )
}
