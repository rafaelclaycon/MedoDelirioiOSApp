//
//  EpisodesView+ViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 01/12/24.
//

import Foundation
import MediaPlayer

extension EpisodesView {

    @MainActor
    final class ViewModel: ObservableObject {

        @Published var state: LoadingState<[Episode]> = .loading
        @Published var playerState: PlayerState<Episode> = .stopped

        var assetPlayer: AssetPlayer!

        private let episodeRepository: EpisodeRepositoryProtocol

        // MARK: - Initializer

        init(
            episodeRepository: EpisodeRepositoryProtocol
        ) {
            self.episodeRepository = episodeRepository
        }
    }
}

// MARK: - User Actions

extension EpisodesView.ViewModel {

    public func onViewLoaded() async {
        await loadEpisodes()
    }

    public func onPlayEpisodeSelected(episode: Episode) async {
        var episodeCopy = episode
        do {
            playerState = .downloading
            episodeCopy.localUrl = try await episodeRepository.localUrl(for: episode)
            play(episode: episodeCopy)
        } catch {
            print(error)
        }
    }

    public func onPlayPauseButtonSelected() {
        print("Not implemented yet")
    }
}

// MARK: - Internal Functions

extension EpisodesView.ViewModel {

    private func loadEpisodes() async {
        state = .loading

        do {
            let episodes = try await episodeRepository.latestEpisodes()
            state = .loaded(episodes)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func play(episode: Episode) {
        guard let url = episode.localUrl else { return }

        playerState = .playing(episode)

        let metadata = NowPlayableStaticMetadata(
            assetURL: url,
            mediaType: .audio,
            isLiveStream: false,
            title: episode.title,
            artist: "Pedro e Cristiano",
            artwork: nil,
            albumArtist: "Pedro e Cristiano",
            albumTitle: "Medo e Delírio em Brasília"
        )

        do {
            assetPlayer = try AssetPlayer()
            assetPlayer.playerItems = [AVPlayerItem(asset: AVURLAsset(url: url))]
            assetPlayer.staticMetadatas = [metadata]
            assetPlayer.play()
        } catch {
            print(error)
        }

//        AudioPlayer.shared = AudioPlayer(
//            url: url,
//            update: { [weak self] state in
//                self?.onAudioPlayerUpdate(playerState: state)
//            }
//        )
//
//        AudioPlayer.shared?.togglePlay(contentTitle: episode.title)
    }

    private func onAudioPlayerUpdate(
        playerState: AudioPlayer.State?
    ) {
        guard playerState?.activity == .stopped else { return }
        self.playerState = .stopped
    }
}
