//
//  SharingUtility.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import UIKit

class SharingUtility {

    static func shareSound(
        from url: URL,
        andContentId contentId: String,
        context contentType: ContentType,
        completionHandler: @escaping (Bool) -> Void
    ) throws {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        DispatchQueue.main.async {
            UIApplication.shared.keyWindow?.rootViewController?.present(activityVC, animated: true, completion: nil)
        }
        activityVC.completionWithItemsHandler = { activity, completed, items, error in
            if completed {
                guard let activity = activity else {
                    return
                }
                let destination = ShareDestination.translateFrom(activityTypeRawValue: activity.rawValue)
                Logger.shared.logShared(contentType, contentId: contentId, destination: destination, destinationBundleId: activity.rawValue)

                AppStoreReviewSteward.requestReviewBasedOnVersionAndCount()
                
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
    
    static func share(
        content: [AnyEquatableMedoContent]
    ) async throws -> Bool {
        guard !content.isEmpty else { return false }
        let urls: [URL] = content.compactMap { try? $0.fileURL() }

        return await withCheckedContinuation { continuation in
            let activityVC = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            DispatchQueue.main.async {
                UIApplication.shared.keyWindow?.rootViewController?.present(activityVC, animated: true, completion: nil)
            }
            activityVC.completionWithItemsHandler = { activity, completed, items, error in
                guard completed else { return continuation.resume(returning: false) }
                guard let activity else { return continuation.resume(returning: true) }

                let destination = ShareDestination.translateFrom(activityTypeRawValue: activity.rawValue)
                content.forEach {
                    guard let contentType = ContentType.shareType(for: $0.type) else {
                        return
                    }
                    Logger.shared.logShared(contentType, contentId: $0.id, destination: destination, destinationBundleId: activity.rawValue)
                }

                AppStoreReviewSteward.requestReviewBasedOnVersionAndCount()

                continuation.resume(returning: true)
            }
        }
    }

    /// Use for video only.
    static func share(
        _ type: ContentType,
        withPath filepath: String,
        andContentId contentId: String,
        shareSheetDelayInSeconds: Double,
        completionHandler: @escaping (Bool) -> Void
    ) throws {
        guard
            filepath.isEmpty == false,
            [.videoFromSound, .videoFromSong].contains(type)
        else { return }

        let url = URL(fileURLWithPath: filepath)
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shareSheetDelayInSeconds) {
            UIApplication.shared.keyWindow?.rootViewController?.present(activityVC, animated: true, completion: nil)
        }
        
        activityVC.completionWithItemsHandler = { activity, completed, items, error in
            if completed {
                guard let activity = activity else {
                    return
                }
                let destination = ShareDestination.translateFrom(activityTypeRawValue: activity.rawValue)
                Logger.shared.logShared(type, contentId: contentId, destination: destination, destinationBundleId: activity.rawValue)

                AppStoreReviewSteward.requestReviewBasedOnVersionAndCount()
                
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }
}

enum SharerError: Error {

    case unableToFindSoundFile
}
