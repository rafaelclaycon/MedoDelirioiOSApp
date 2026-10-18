//
//  TranscriptDiffTests.swift
//  MedoDelirioBrasiliaTests
//
//  Created by Rafael Schmitt on 18/10/26.
//

import Testing
import Foundation
@testable import MedoDelirio

struct TranscriptDiffTests {

    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptDiffTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - Helpers

    /// Writes an SRT for the episode and returns its hash, as the manifest would list it.
    @discardableResult
    private func writeFile(_ episodeId: String, contents: String) throws -> String {
        let data = Data(contents.utf8)
        try data.write(to: directory.appendingPathComponent("\(episodeId).srt"))
        return TranscriptDownloadService.sha256Hex(data)
    }

    private func manifest(_ entries: [(String, String)]) -> TranscriptManifest {
        TranscriptManifest(
            version: 1,
            files: entries.map { TranscriptFileEntry(episodeId: $0.0, hash: $0.1, size: 0) }
        )
    }

    private func diff(
        _ manifest: TranscriptManifest,
        knownHashes: [String: String]
    ) -> (filesToDownload: [String], learnedHashes: [String: String]) {
        let result = TranscriptDownloadService.diffAgainstLocal(
            manifest: manifest,
            knownHashes: knownHashes,
            directory: directory
        )
        return (result.filesToDownload.map(\.episodeId), result.learnedHashes)
    }

    // MARK: - Known hashes

    @Test
    func diff_withMatchingKnownHash_shouldSkipFile() throws {
        let hash = try writeFile("ep1", contents: "one")

        let result = diff(manifest([("ep1", hash)]), knownHashes: ["ep1": hash])

        #expect(result.filesToDownload.isEmpty)
        #expect(result.learnedHashes.isEmpty)
    }

    @Test
    func diff_withOutdatedKnownHash_shouldDownloadFile() throws {
        let oldHash = try writeFile("ep1", contents: "old")

        let result = diff(manifest([("ep1", "new-hash")]), knownHashes: ["ep1": oldHash])

        #expect(result.filesToDownload == ["ep1"])
    }

    @Test
    func diff_withKnownHash_shouldTrustIndexOverDisk() throws {
        // The index is the source of truth once it has an entry: the file isn't read.
        try writeFile("ep1", contents: "whatever is on disk")

        let result = diff(manifest([("ep1", "indexed-hash")]), knownHashes: ["ep1": "indexed-hash"])

        #expect(result.filesToDownload.isEmpty)
        #expect(result.learnedHashes.isEmpty)
    }

    @Test
    func diff_withKnownHashButMissingFile_shouldDownloadFile() {
        let result = diff(manifest([("ep1", "hash")]), knownHashes: ["ep1": "hash"])

        #expect(result.filesToDownload == ["ep1"])
    }

    // MARK: - Files missing from the index

    @Test
    func diff_withUnindexedMatchingFile_shouldLearnHashAndSkip() throws {
        let hash = try writeFile("ep1", contents: "one")

        let result = diff(manifest([("ep1", hash)]), knownHashes: [:])

        #expect(result.filesToDownload.isEmpty)
        #expect(result.learnedHashes == ["ep1": hash])
    }

    @Test
    func diff_withUnindexedOutdatedFile_shouldLearnHashAndDownload() throws {
        let localHash = try writeFile("ep1", contents: "old")

        let result = diff(manifest([("ep1", "new-hash")]), knownHashes: [:])

        #expect(result.filesToDownload == ["ep1"])
        #expect(result.learnedHashes == ["ep1": localHash])
    }

    @Test
    func diff_withNewEpisode_shouldDownloadWithoutLearningAnything() {
        let result = diff(manifest([("ep1", "hash")]), knownHashes: [:])

        #expect(result.filesToDownload == ["ep1"])
        #expect(result.learnedHashes.isEmpty)
    }

    // MARK: - Mixed

    @Test
    func diff_withMixedCatalog_shouldDownloadOnlyWhatChanged() throws {
        let unchanged = try writeFile("unchanged", contents: "a")
        let unindexed = try writeFile("unindexed", contents: "b")
        try writeFile("changed", contents: "c")

        let result = diff(
            manifest([
                ("unchanged", unchanged),
                ("unindexed", unindexed),
                ("changed", "changed-on-server"),
                ("brand-new", "new")
            ]),
            knownHashes: [
                "unchanged": unchanged,
                "changed": TranscriptDownloadService.sha256Hex(Data("c".utf8))
            ]
        )

        #expect(result.filesToDownload == ["changed", "brand-new"])
        #expect(result.learnedHashes == ["unindexed": unindexed])
    }

    @Test
    func diff_withMissingDirectory_shouldDownloadEverything() {
        let result = TranscriptDownloadService.diffAgainstLocal(
            manifest: manifest([("ep1", "a"), ("ep2", "b")]),
            knownHashes: ["ep1": "a"],
            directory: directory.appendingPathComponent("does-not-exist")
        )

        #expect(result.filesToDownload.map(\.episodeId) == ["ep1", "ep2"])
    }
}
