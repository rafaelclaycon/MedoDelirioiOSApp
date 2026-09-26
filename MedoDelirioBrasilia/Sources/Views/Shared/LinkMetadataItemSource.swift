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
