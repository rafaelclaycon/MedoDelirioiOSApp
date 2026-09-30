import LinkPresentation
import SwiftUI
import UIKit

// MARK: - Rich-preview share item

/// Hands `UIActivityViewController` pre-fetched `LPLinkMetadata` so the share sheet
/// always shows the correct image instead of the server's fallback icon. Present it with
/// `.shareSheet(item:activityItems:)`.
final class LinkMetadataItemSource: NSObject, UIActivityItemSource {

    private let metadata: LPLinkMetadata

    init(metadata: LPLinkMetadata) {
        self.metadata = metadata
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        metadata.url ?? URL(string: "https://medodelirioios.com")!
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        metadata.url
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        metadata
    }
}

// MARK: - Image share item

/// Shares an image with a proper share sheet header: the image as the thumbnail, a title
/// saying what it is and the app's site underneath. A bare `UIImage` gets a blank title and
/// a generic placeholder icon.
final class ImageShareItemSource: NSObject, UIActivityItemSource {

    private let image: UIImage
    private let metadata: LPLinkMetadata

    init(image: UIImage, title: String) {
        self.image = image
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.url = URL(string: "https://medodelirioios.com")
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        self.metadata = metadata
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        metadata
    }
}
