//
//  TranscriptProvider.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 21/03/26.
//

import Foundation

enum TranscriptState: Equatable {

    case idle
    case notAvailable(reason: String, isComingSoon: Bool = false)
    case loaded(cues: [SRTCue])
}

@Observable
final class TranscriptProvider {

    // MARK: - Observable State

    private(set) var state: TranscriptState = .idle
    private(set) var previousCue: SRTCue?
    private(set) var currentCue: SRTCue?
    private(set) var nextCue: SRTCue?

    // MARK: - Private

    @ObservationIgnored private var cues: [SRTCue] = []
    @ObservationIgnored private var lastCueIndex: Int?

    // MARK: - Loading

    func load(episodeId: String?, pubDate: Date? = nil) {
        cues = []
        lastCueIndex = nil
        previousCue = nil
        currentCue = nil
        nextCue = nil

        guard let episodeId, !episodeId.isEmpty else {
            state = .notAvailable(reason: "Nenhum episódio selecionado.")
            return
        }

        guard let fileURL = Self.findSRTFile(for: episodeId) else {
            if let pubDate, Self.isRecent(pubDate) {
                state = .notAvailable(
                    reason: "Transcrição a caminho! Episódios recentes podem levar alguns dias.",
                    isComingSoon: true
                )
            } else {
                state = .notAvailable(reason: "Transcrição não encontrada para esse episódio.")
            }
            return
        }

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            state = .notAvailable(reason: "Não foi possível ler o arquivo de transcrição.")
            return
        }

        let parsed = SRTParser.parse(content)
        guard !parsed.isEmpty else {
            state = .notAvailable(reason: "Arquivo SRT vazio ou inválido.")
            return
        }

        cues = parsed
        state = .loaded(cues: parsed)
    }

    // MARK: - Time Update

    /// Call this with the current playback time to update the active cues.
    func update(currentTime: TimeInterval) {
        guard !cues.isEmpty else { return }

        let index = findCueIndex(for: currentTime)

        guard index != lastCueIndex else { return }
        lastCueIndex = index

        if let index {
            previousCue = index > 0 ? cues[index - 1] : nil
            currentCue = cues[index]
            nextCue = index < cues.count - 1 ? cues[index + 1] : nil
        } else {
            let upcoming = cues.firstIndex { $0.startTime > currentTime }
            previousCue = nil
            currentCue = nil
            nextCue = upcoming.map { cues[$0] }
        }
    }

    // MARK: - Binary Search

    /// Returns the index of the cue active at `time`, or nil if between cues.
    private func findCueIndex(for time: TimeInterval) -> Int? {
        var low = 0
        var high = cues.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let cue = cues[mid]

            if time < cue.startTime {
                high = mid - 1
            } else if time > cue.endTime {
                low = mid + 1
            } else {
                return mid
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static func isRecent(_ date: Date) -> Bool {
        let daysSincePublished = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        return daysSincePublished < 5
    }

    // MARK: - File Path

    /// Finds an SRT file whose name starts with the episode ID.
    /// Matches `{episodeId}.srt`, `{episodeId}-anything.srt`, etc.
    static func findSRTFile(for episodeId: String) -> URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let transcriptsDir = documentsURL.appendingPathComponent(InternalFolderNames.transcripts)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: transcriptsDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let prefix = episodeId
        return contents.first { url in
            guard url.pathExtension.lowercased() == "srt" else { return false }
            let stem = url.deletingPathExtension().lastPathComponent
            guard stem.hasPrefix(prefix) else { return false }
            if stem.count == prefix.count { return true }
            let charAfter = stem[stem.index(stem.startIndex, offsetBy: prefix.count)]
            return charAfter == "-" || charAfter == "_" || charAfter == "."
        }
    }
}
