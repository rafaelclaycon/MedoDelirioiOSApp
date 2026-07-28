//
//  ShareAsVideoViewModel.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 22/02/23.
//

import SwiftUI
import PhotosUI

@Observable
class ShareAsVideoViewModel {

    var content: AnyEquatableMedoContent
    var subtitle: String
    private let type: ContentType
    private var result: Binding<ShareAsVideoResult>

    var includeSoundWarning: Bool = true
    var isShowingProcessingView = false

    var shouldCloseView = false
    var pathToVideoFile = ""
    var selectedSocialNetwork = IntendedVideoDestination.twitter.rawValue
    var selectedBackground = ShareAsVideoBackground.green

    // Alerts
    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false

    // MARK: - Initializer

    init(
        content: AnyEquatableMedoContent,
        subtitle: String = "",
        contentType: ContentType,
        result: Binding<ShareAsVideoResult>
    ) {
        self.content = content
        self.subtitle = subtitle
        self.type = contentType
        self.result = result
    }
}

// MARK: - User Actions

extension ShareAsVideoViewModel {

    public func onViewAppeared() {
        // Cleaning this string is needed in case the user decides do re-export the same sound.
        result.wrappedValue = ShareAsVideoResult(videoFilepath: "", contentId: "", exportMethod: .shareSheet)
    }

    public func onSaveVideoSelected(_ image: UIImage) async {
        guard let videoPath = await saveVideoToPhotos(withImage: image) else { return }
        result.wrappedValue = ShareAsVideoResult(
            videoFilepath: videoPath,
            contentId: content.id,
            exportMethod: .saveAsVideo
        )
        shouldCloseView = true
    }

    public func onShareVideoSelected(_ image: UIImage) async {
        guard
            let videoPath = await generateVideo(withImage: image)
        else { return }
        isShowingProcessingView = false
        result.wrappedValue = ShareAsVideoResult(
            videoFilepath: videoPath,
            contentId: content.id,
            exportMethod: .shareSheet
        )
        shouldCloseView = true
    }
}

// MARK: - Internal Functions

extension ShareAsVideoViewModel {

    private func generateVideo(withImage image: UIImage) async -> String? {
        isShowingProcessingView = true

        do {
            return try await VideoMaker.createVideo(
                from: content,
                with: image,
                exportType: IntendedVideoDestination(rawValue: selectedSocialNetwork)!
            )
        } catch VideoMakerError.soundFilepathIsEmpty {
            isShowingProcessingView = false
            showOtherError(
                errorTitle: Shared.contentNotFoundAlertTitle(""),
                errorBody: Shared.contentNotFoundAlertMessage
            )
            return nil
        } catch {
            isShowingProcessingView = false
            showOtherError(
                errorTitle: "Falha na Geração do Vídeo",
                errorBody: error.localizedDescription
            )
            return nil
        }
    }

    private func saveVideoToPhotos(withImage image: UIImage) async -> String? {
        isShowingProcessingView = true

        // Create video album
//        let photos = PHPhotoLibrary.authorizationStatus()
//        if photos == .notDetermined {
//            PHPhotoLibrary.requestAuthorization({status in
//                if status == .authorized {
//                    CustomPhotoAlbum.sharedInstance.requestAuthorizationHandler(status: .authorized)
//                } else {
//                    print(status)
//                }
//            })
//        } else {
//            CustomPhotoAlbum.sharedInstance.requestAuthorizationHandler(status: .authorized)
//        }

        guard
            let videoPath = await generateVideo(withImage: image)
        else { return nil }

        do {
            try await CustomPhotoAlbum.shared.save(video: URL(fileURLWithPath: videoPath))

            isShowingProcessingView = false
            Logger.shared.logShared(
                self.type,
                contentId: self.content.id,
                destination: .other,
                destinationBundleId: Shared.BundleIds.applePhotosApp
            )
            return videoPath
        } catch {
            isShowingProcessingView = false
            showOtherError(
                errorTitle: "Falha na Geração do Vídeo",
                errorBody: error.localizedDescription
            )
            return nil
        }
    }

    private func showOtherError(errorTitle: String, errorBody: String) {
        alertTitle = errorTitle
        alertMessage = errorBody
        showAlert = true
    }
}
