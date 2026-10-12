//
//  GameRound.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 12/10/26.
//

import Foundation

/// One question: something to look at or listen to, and the authors to pick from.
struct GameRound: Identifiable, Equatable {

    enum Prompt: Equatable {
        /// The author's photo URL.
        case photo(String)
        case sound(Sound)
    }

    let id = UUID()
    let prompt: Prompt
    /// Includes `answer`, in the order shown.
    let options: [Author]
    let answer: Author
}

/// Builds a game's rounds from the catalog. Pure, so tests can pass a seeded generator.
enum GameRoundFactory {

    static let optionCount = 4
    static let roundCount = 10
    /// Extra rounds to build, to stand in for any that turn out unplayable.
    static let spareCount = 10

    /// Shortest sound worth guessing from. Zero means the duration is unknown, which
    /// is let through.
    static let minimumSoundDuration: Double = 1.5

    /// A round per author with a photo, up to `count`, never repeating an author as the
    /// answer. Empty when there aren't enough authors with photos for four options.
    static func faceRounds(
        authors: [Author],
        count: Int = roundCount,
        using generator: inout some RandomNumberGenerator
    ) -> [GameRound] {
        let withPhotos = unique(authors.filter { $0.photo?.isEmpty == false })
        guard withPhotos.count >= optionCount else { return [] }

        return withPhotos.shuffled(using: &generator).prefix(count).compactMap { answer in
            guard let photo = answer.photo else { return nil }
            return GameRound(
                prompt: .photo(photo),
                options: options(for: answer, from: withPhotos, using: &generator),
                answer: answer
            )
        }
    }

    /// A round per author with sounds, up to `count`, each with one of their sounds,
    /// never repeating an author as the answer. The wrong options are other authors
    /// with sounds, so they're plausible. Empty when fewer than four authors have sounds.
    static func voiceRounds(
        sounds: [Sound],
        authors: [Author],
        count: Int = roundCount,
        using generator: inout some RandomNumberGenerator
    ) -> [GameRound] {
        let authorsByID = Dictionary(unique(authors).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let usable = sounds.filter {
            authorsByID[$0.authorId] != nil && ($0.duration == 0 || $0.duration >= minimumSoundDuration)
        }
        let soundsByAuthor = Dictionary(grouping: usable, by: \.authorId)
        // Sorted first so a seeded generator gives the same game every time.
        let voiced = soundsByAuthor.keys.sorted().compactMap { authorsByID[$0] }
        guard voiced.count >= optionCount else { return [] }

        return voiced.shuffled(using: &generator).prefix(count).compactMap { answer in
            guard let sound = soundsByAuthor[answer.id]?.sorted(by: { $0.id < $1.id }).randomElement(using: &generator) else {
                return nil
            }
            return GameRound(
                prompt: .sound(sound),
                options: options(for: answer, from: voiced, using: &generator),
                answer: answer
            )
        }
    }

    // MARK: - Helpers

    /// The answer and three others, shuffled. Skips anyone sharing the answer's name,
    /// which would leave two identical buttons.
    private static func options(
        for answer: Author,
        from pool: [Author],
        using generator: inout some RandomNumberGenerator
    ) -> [Author] {
        let others = pool
            .filter { $0.id != answer.id && $0.name != answer.name }
            .shuffled(using: &generator)
        var names: Set<String> = [answer.name]
        var picked: [Author] = []
        for author in others where picked.count < optionCount - 1 {
            if names.insert(author.name).inserted {
                picked.append(author)
            }
        }
        return (picked + [answer]).shuffled(using: &generator)
    }

    private static func unique(_ authors: [Author]) -> [Author] {
        var seen = Set<String>()
        return authors.filter { seen.insert($0.id).inserted }
    }
}
