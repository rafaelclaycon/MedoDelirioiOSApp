//
//  GameMusicPlayer.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import AVFoundation
import Foundation

/// Background music for a game: one of the app's songs, picked at random each game,
/// looping quietly. Muting is remembered across games.
///
/// Its own `AVAudioPlayer` rather than `AudioPlayer`, which can't loop or set a
/// volume. Not logged as a play, so it stays out of Tendências.
@Observable
@MainActor
final class GameMusicPlayer {

    nonisolated static let mutedKey = "gameMusicMuted"
    /// Quiet enough to sit under the game, not compete with it.
    static let volume: Float = 0.35
    /// Shorter songs loop too often to be background music.
    static let minimumDuration: TimeInterval = 30

    private(set) var isMuted: Bool
    /// The title of the song playing, for the screen to show. Nil when nothing plays.
    private(set) var songTitle: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var player: AVAudioPlayer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isMuted = defaults.bool(forKey: Self.mutedKey)
    }

    /// Starts a new random song longer than `minimumDuration`, respecting the explicit
    /// content setting. Plays even when muted, at no volume, so unmuting picks it up
    /// mid-song.
    func playRandomSong() {
        stop()

        let allowSensitive = UserSettings().getShowExplicitContent()
        let songs = ((try? LocalDatabase.shared.songs(allowSensitive: allowSensitive)) ?? [])
            // Known to be too short. Unknown (0) is checked against the file below.
            .filter { $0.duration == 0 || $0.duration > Self.minimumDuration }
            .shuffled()

        // The file's own duration decides, since the catalog's can be missing or off.
        guard let (song, player) = songs.lazy
            .compactMap({ song in (try? song.fileURL()).map { (song, $0) } })
            .compactMap({ song, url in (try? AVAudioPlayer(contentsOf: url)).map { (song, $0) } })
            .first(where: { $0.1.duration > Self.minimumDuration })
        else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            player.numberOfLoops = -1
            player.volume = isMuted ? 0 : Self.volume
            player.play()
            self.player = player
            songTitle = song.title
        } catch {
            // No audio session, no music; the game plays on without it.
            self.player = nil
        }
    }

    func toggleMute() {
        isMuted.toggle()
        defaults.set(isMuted, forKey: Self.mutedKey)
        player?.setVolume(isMuted ? 0 : Self.volume, fadeDuration: 0.3)
    }

    func stop() {
        player?.stop()
        player = nil
        songTitle = nil
    }
}
