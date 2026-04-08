//
//  TrendsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/05/22.
//

import SwiftUI

struct TrendsView: View {

    enum ViewMode: Int {
        case audience, me
    }

    @State public var audienceViewModel: MostSharedByAudienceView.ViewModel
    @State private var toast: Toast?

    @Binding var tabSelection: PhoneTab
    @Binding var activePadScreen: PadScreen?
    @State var currentViewMode: ViewMode = .audience

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
                    Picker("Exibição", selection: $currentViewMode) {
                        Text("🏆  Da Audiência")
                            .tag(ViewMode.audience)

                        Text("🧑  Pessoais")
                            .tag(ViewMode.me)
                    }
                    .pickerStyle(.segmented)
                    .padding(.all)

                    if currentViewMode == .audience {
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
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            MostSharedByMeView()
                                .environment(trendsHelper)

                            Divider()
                                .padding(.horizontal)
                                .padding(.vertical, .spacing(.small))

                            EpisodeStatsView()
                        }
                    }
                }
                .if(currentViewMode == .audience) {
                    $0.refreshable {
                        await audienceViewModel.onPullToRefreshLists()
                    }
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
