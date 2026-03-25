//
//  StorageHelper.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/03/26.
//

import Foundation

enum StorageHelper {

    static func sizeOfDirectory(at url: URL) throws -> UInt64 {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var totalSize: UInt64 = 0

        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard resourceValues.isRegularFile == true else { continue }
            totalSize += UInt64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }

    static func formattedSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func fileCount(in directoryURL: URL) -> Int {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else { return 0 }

        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        var count = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true { count += 1 }
        }
        return count
    }

    static func removeAllFiles(in directoryURL: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directoryURL.path) else { return }

        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }

    static func removeFiles(forEpisodeIDs ids: Set<String>, in directoryURL: URL) -> Int {
        let fileManager = FileManager.default
        var deletedCount = 0
        for id in ids {
            let filename = EpisodePlayer.sanitizedFilename(for: id)
            let fileURL = directoryURL.appendingPathComponent("\(filename).mp3")
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
                deletedCount += 1
            }
        }
        return deletedCount
    }
}
