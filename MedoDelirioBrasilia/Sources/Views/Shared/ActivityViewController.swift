import LinkPresentation
import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var completionWithItemsHandler: UIActivityViewController.CompletionWithItemsHandler?
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.completionWithItemsHandler = completionWithItemsHandler
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}

// MARK: - Rich-preview share sheet

/// Wraps `UIActivityViewController` with pre-fetched `LPLinkMetadata` so the
/// share sheet always shows the correct image instead of the server's fallback icon.
struct LinkMetadataShareSheet: UIViewControllerRepresentable {

    let metadata: LPLinkMetadata
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = LinkMetadataItemSource(metadata: metadata)
        let vc = UIActivityViewController(activityItems: [source], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in dismiss() }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

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
