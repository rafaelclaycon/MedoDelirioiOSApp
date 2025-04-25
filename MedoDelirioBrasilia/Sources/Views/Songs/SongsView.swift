//
//  SongsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/05/22.
//

import SwiftUI

struct SongsView: View {

    @State private var viewModel = SongsViewViewModel(database: LocalDatabase.shared, logger: Logger.shared)

    @State private var currentGenre: String? = nil
    @State private var showGenrePicker = false

    // Share as Video
    @State private var shareAsVideo_Result = ShareAsVideoResult()

    @Environment(TrendsHelper.self) private var trendsHelper
    @EnvironmentObject var settingsHelper: SettingsHelper

    // Dynamic Type
    @ScaledMetric private var explicitOffWarningTopPadding = 16
    @ScaledMetric private var explicitOffWarningBottomPadding = 20
    @ScaledMetric private var songCountTopPadding = 10
    @ScaledMetric private var songCountBottomPadding = 22

    // MARK: - Computed Properties

    private var columns: [GridItem] {
        if UIDevice.isiPhone {
            return [GridItem(.flexible())]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    private var searchResults: [Song] {
        if viewModel.searchText.isEmpty {
            guard let currentGenre else { return viewModel.songs }
            return viewModel.songs.filter({ $0.genreId == currentGenre })
        } else {
            return viewModel.songs.filter { song in
                let searchString = song.title.lowercased().withoutDiacritics()
                return searchString.contains(viewModel.searchText.lowercased().withoutDiacritics())
            }
        }
    }

    // MARK: - View Body

    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVGrid(columns: columns, spacing: 14) {
                            if searchResults.isEmpty {
                                NoSearchResultsView(searchText: $viewModel.searchText)
                            } else {
                                ForEach(searchResults) { song in
                                    SongView(
                                        song: song,
                                        nowPlaying: $viewModel.nowPlayingKeeper,
                                        highlighted: $viewModel.highlightKeeper
                                    )
                                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .padding(.horizontal, UIDevice.current.userInterfaceIdiom == .phone ? 0 : 5)
                                    .onTapGesture {
                                        if viewModel.nowPlayingKeeper.contains(song.id) {
                                            AudioPlayer.shared?.togglePlay(contentTitle: song.title)
                                            viewModel.nowPlayingKeeper.removeAll()
                                        } else {
                                            viewModel.play(song: song)
                                        }
                                    }
                                    .contextMenu(menuItems: {
                                        Section {
                                            Button {
                                                viewModel.share(song: song)
                                            } label: {
                                                Label(Shared.shareSongButtonText, systemImage: "square.and.arrow.up")
                                            }

                                            Button {
                                                viewModel.songToShareAsVideo = song
                                            } label: {
                                                Label(Shared.shareAsVideoButtonText, systemImage: "film")
                                            }
                                        }

                                        Section {
                                            Button {
                                                viewModel.selectedSong = song
                                                viewModel.showEmailAppPicker_suggestChangeConfirmationDialog = true
                                            } label: {
                                                Label("Sugerir Alteração", systemImage: "exclamationmark.bubble")
                                            }
                                        }
                                    })
                                }
                            }
                        }
                        .searchable(text: $viewModel.searchText)
                        .disableAutocorrection(true)
                        .padding(.horizontal)
                        .padding(.top, 7)
                        .onChange(of: trendsHelper.songIdToGoTo) {
                            if !trendsHelper.songIdToGoTo.isEmpty {
                                viewModel.cancelSearchAndHighlight(id: trendsHelper.songIdToGoTo)
                                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(600)) {
                                    withAnimation {
                                        proxy.scrollTo(trendsHelper.songIdToGoTo, anchor: .center)
                                    }
                                    TapticFeedback.warning()
                                    trendsHelper.songIdToGoTo = ""
                                }
                            }
                        }

                        if UserSettings().getShowExplicitContent() == false {
                            ExplicitDisabledWarning(
                                text: UIDevice.current.userInterfaceIdiom == .phone ? Shared.contentFilterMessageForSongsiPhone : Shared.contentFilterMessageForSongsiPadMac
                            )
                            .padding(.top, explicitOffWarningTopPadding)
                            .padding(.horizontal, explicitOffWarningBottomPadding)
                        }

                        if viewModel.searchText.isEmpty, currentGenre == nil {
                            Text("\(viewModel.songs.count) MÚSICAS")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.top, songCountTopPadding)
                                .padding(.bottom, songCountBottomPadding)
                        }
                    }
                }
            }
            .navigationTitle("Músicas")
            .navigationBarItems(leading:
                getLeadingToolbarControl()
            )
            .toolbar {
                Menu {
                    Section {
                        Picker("Ordenação", selection: $viewModel.sortOption) {
                            Text("Título")
                                .tag(0)
                            
                            Text("Mais Recentes no Topo")
                                .tag(1)
                            
                            Text("Mais Longas no Topo")
                                .tag(2)
                            
                            Text("Mais Curtas no Topo")
                                .tag(3)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .onChange(of: viewModel.sortOption) {
                    viewModel.sortSongs(by: SongSortOption(rawValue: $0) ?? .dateAddedDescending)
                    UserSettings().setSongSortOption(to: $0)
                }
                .onChange(of: shareAsVideo_Result.videoFilepath) {
                    if shareAsVideo_Result.videoFilepath.isEmpty == false {
                        if shareAsVideo_Result.exportMethod == .saveAsVideo {
                            viewModel.showVideoSavedSuccessfullyToast()
                        } else {
                            viewModel.shareVideo(withPath: shareAsVideo_Result.videoFilepath, andContentId: shareAsVideo_Result.contentId)
                        }
                    }
                }
            }
            .onAppear {
                viewModel.reloadList()
                viewModel.donateActivity()

                Analytics().send(
                    originatingScreen: "SongsView",
                    action: "didViewSongsTab"
                )
            }
            .onDisappear {
                AudioPlayer.shared?.cancel()
                viewModel.nowPlayingKeeper.removeAll()
            }
            .sheet(isPresented: $viewModel.isShowingShareSheet) {
                viewModel.iPadShareSheet
            }
            .sheet(isPresented: $viewModel.showEmailAppPicker_suggestChangeConfirmationDialog) {
                EmailAppPickerView(
                    isBeingShown: $viewModel.showEmailAppPicker_suggestChangeConfirmationDialog,
                    subject: String(format: Shared.Email.suggestSongChangeSubject, viewModel.selectedSong?.title ?? ""),
                    emailBody: String(format: Shared.Email.suggestSongChangeBody, viewModel.selectedSong?.id ?? ""),
                    afterCopyAddressAction: {}
                )
            }
            .sheet(item: $viewModel.songToShareAsVideo) { song in
                ShareAsVideoView(
                    viewModel: ShareAsVideoViewViewModel(content: song, contentType: .videoFromSong),
                    result: $shareAsVideo_Result,
                    useLongerGeneratingVideoMessage: true
                )
            }
            .sheet(isPresented: $showGenrePicker) {
                GenrePickerView(selectedId: $currentGenre)
            }
            .sheet(isPresented: $viewModel.showEmailAppPicker_songUnavailableConfirmationDialog) {
                EmailAppPickerView(
                    isBeingShown: $viewModel.showEmailAppPicker_songUnavailableConfirmationDialog,
                    subject: Shared.issueSuggestionEmailSubject,
                    emailBody: Shared.issueSuggestionEmailBody,
                    afterCopyAddressAction: {}
                )
            }
            .alert(isPresented: $viewModel.showAlert) {
                switch viewModel.alertType {
                case .ok:
                    return Alert(
                        title: Text(viewModel.alertTitle), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK"))
                    )

                case .redownloadSong:
                    return Alert(
                        title: Text(viewModel.alertTitle),
                        message: Text(viewModel.alertMessage),
                        primaryButton: .default(Text("Baixar Conteúdo Novamente"), action: {
                        guard let content = viewModel.selectedSong else { return }
                        viewModel.redownloadServerContent(withId: content.id)
                    }), secondaryButton: .cancel(Text("Fechar"))
                    )

                case .songUnavailable:
                    return Alert(
                        title: Text(viewModel.alertTitle),
                        message: Text(viewModel.alertMessage),
                        primaryButton: .default(
                            Text("Relatar Problema por E-mail"),
                            action: {
                                viewModel.showEmailAppPicker_songUnavailableConfirmationDialog = true
                            }
                        ),
                        secondaryButton: .cancel(Text("Fechar"))
                    )
                }
            }
            .onReceive(settingsHelper.$updateSoundsList) { shouldUpdate in
                if shouldUpdate {
                    viewModel.reloadList()
                    settingsHelper.updateSoundsList = false
                }
            }

            if viewModel.showToastView {
                VStack {
                    Spacer()
                    
                    ToastView(
                        icon: viewModel.toastIcon,
                        iconColor: viewModel.toastIconColor,
                        text: viewModel.toastText
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 15)
                }
                .transition(.moveAndFade)
            }

            if viewModel.isShowingProcessingView {
                ProcessingView(message: "Baixando música...")
                    .padding(.bottom)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder func getLeadingToolbarControl() -> some View {
        Button {
            showGenrePicker.toggle()
        } label: {
            Image(
                systemName: currentGenre == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    SongsView()
}
