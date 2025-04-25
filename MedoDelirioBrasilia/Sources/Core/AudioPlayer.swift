//
//  AudioPlayer.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 19/05/22.
//

import Foundation
import AVFoundation
import MediaPlayer

/// A class that manages audio playback using `AVAudioPlayer` with additional state management and updates.
///
/// This class supports toggling playback, tracking playback progress, and notifying about state changes.
/// It is designed to be used as a singleton with the `shared` property.
///
/// - Note: This class requires an active audio session with the `AVAudioSession.Category.playback` category.
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {

    enum Activity {
        case stopped
        case playing
        case paused
    }

    struct State {
        var currentTime: TimeInterval
        var duration: TimeInterval
        var activity: Activity
    }

    private var audioPlayer: AVAudioPlayer
    private var timer: Timer?
    private var update: (State?) -> Void

    static var shared: AudioPlayer?

    init?(
        url: URL,
        update: @escaping (State?) -> Void
    ) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return nil
        }

        if let player = try? AVAudioPlayer(contentsOf: url) {
            audioPlayer = player
            self.update = update
        } else {
            return nil
        }

        super.init()

        audioPlayer.delegate = self
    }

    func togglePlay(contentTitle: String) {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
            timer?.invalidate()
            timer = nil
            notify()
        } else {
            audioPlayer.prepareToPlay()

            configureNowPlayingInfo(
                title: contentTitle,
                artist: "Cristiano e Pedro",
                album: "Medo e Delírio",
                coverImage: nil
            )

            audioPlayer.play()
            if let t = timer {
                t.invalidate()
            }
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                guard let s = self else { return }
                s.notify()
            }
        }
    }

    var state: AudioPlayer.State {
        State(currentTime: audioPlayer.currentTime, duration: audioPlayer.duration, activity: activity)
    }

    func notify() {
        update(state)
    }

    func setProgress(_ time: TimeInterval) {
        audioPlayer.currentTime = time
        notify()
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
        timer?.invalidate()
        timer = nil
        if flag {
            notify()
        } else {
            update(nil)
        }
    }

    var duration: TimeInterval {
        audioPlayer.duration
    }

    var activity: Activity {
        audioPlayer.isPlaying ? .playing : isPaused ? .paused : .stopped
    }
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }

    var isPaused: Bool {
        !audioPlayer.isPlaying && audioPlayer.currentTime > 0
    }
    
    func stop() {
        audioPlayer.stop()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        timer?.invalidate()
        timer = nil
        notify()
    }

    func cancel() {
        audioPlayer.stop()
        timer?.invalidate()
    }
    
    func prepareToPlay() {
        audioPlayer.prepareToPlay()
    }

    deinit {
        cancel()
    }

    private func configureNowPlayingInfo(
        title: String,
        artist: String,
        album: String,
        coverImage: UIImage?
    ) {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: audioPlayer.duration, // Total duration
            MPNowPlayingInfoPropertyElapsedPlaybackTime: audioPlayer.currentTime, // Current playback time
            MPNowPlayingInfoPropertyPlaybackRate: 1.0 // Playback rate
        ]

        if let image = coverImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}
