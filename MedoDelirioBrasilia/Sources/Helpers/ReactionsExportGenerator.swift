//
//  ReactionsExportGenerator.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 20/08/26.
//

import Foundation

/// Dev-only export of the sound catalog and existing Reaction titles, used
/// offline to feed a Claude-based script that suggests new Reactions.
enum ReactionsExportGenerator {

    struct ExportSound: Codable {

        let id: String
        let title: String
        let authorName: String
    }

    struct ExportReactionExample: Codable {

        let title: String
        let soundTitles: [String]
    }

    struct ExportData: Codable {

        let sounds: [ExportSound]
        let existingReactionTitles: [String]
        let sampleReactions: [ExportReactionExample]
    }

    /// How many existing Reactions to include as few-shot examples of tone/sizing.
    private static let sampleReactionCount = 8

    static func generate() async throws -> URL {
        let contentRepository = ContentRepository(database: LocalDatabase.shared)
        let reactionRepository = ReactionRepository()

        let sounds = try contentRepository.allContent(true, .titleAscending)
            .filter { $0.type == .sound }
            .map { ExportSound(id: $0.id, title: $0.title, authorName: $0.subtitle) }
        let soundTitlesById = Dictionary(uniqueKeysWithValues: sounds.map { ($0.id, $0.title) })

        let existingReactions = try await reactionRepository.allReactions()
        let existingReactionTitles = existingReactions.map(\.title)

        var sampleReactions: [ExportReactionExample] = []
        for reaction in existingReactions.shuffled().prefix(sampleReactionCount) {
            let content = try await reactionRepository.reactionContent(reactionId: reaction.id)
            let soundTitles = content.compactMap { soundTitlesById[$0.soundId] }
            guard !soundTitles.isEmpty else { continue }
            sampleReactions.append(ExportReactionExample(title: reaction.title, soundTitles: soundTitles))
        }

        let export = ExportData(
            sounds: sounds,
            existingReactionTitles: existingReactionTitles,
            sampleReactions: sampleReactions
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reactions_export.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
