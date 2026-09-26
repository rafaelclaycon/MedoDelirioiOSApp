//
//  ShareSheet.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/09/26.
//

import SwiftUI
import UIKit

extension View {

    /// Presents the system share sheet for `item` while it's non-nil, anchored to this
    /// view, and sets it back to nil once the sheet is dismissed.
    ///
    /// Presented by UIKit rather than as the content of a SwiftUI `.sheet`, so
    /// `UIActivityViewController` picks its own presentation: the usual sheet at compact
    /// width, and at regular width (iPad, unfolded iPhone Duo) a popover pointing at this
    /// view. Wrapped in a SwiftUI sheet it showed up in a centered card that jumped as it
    /// resized, or blank on iPad.
    ///
    /// Attach it to the view the share started from, such as the item whose context menu
    /// offered Compartilhar. Not in a toolbar: the UIKit anchor turns the item into a
    /// custom-view item, which glitches there — use `LinkShareButton` instead.
    ///
    /// `onComplete` gets the item that was shared, the activity picked (nil when there
    /// was none), and whether it completed. It also runs, with `completed` false, if the
    /// sheet couldn't be presented at all.
    func shareSheet<Item>(
        item: Binding<Item?>,
        activityItems: @escaping (Item) -> [Any],
        onComplete: ((Item, UIActivity.ActivityType?, Bool) -> Void)? = nil
    ) -> some View {
        background(
            ShareSheetAnchor(item: item, activityItems: activityItems, onComplete: onComplete)
        )
    }

    /// Presents `request` while it's non-nil, anchored to this view — for shares a view
    /// model starts: it sets the request, and the view the share came from presents it.
    ///
    /// If several views see the same request (the same sound shown twice on screen), the
    /// first to present it claims it and the rest skip it, so it's shown once.
    ///
    /// `sourceRect` picks the part of this view the popover points at, from its bounds —
    /// for when the control the share came from can't carry the anchor itself (a toolbar
    /// button). By default it points at the whole view.
    func shareSheet(
        request: Binding<ShareRequest?>,
        sourceRect: ((CGRect) -> CGRect)? = nil
    ) -> some View {
        background(
            ShareSheetAnchor(
                item: request,
                activityItems: \.items,
                onComplete: { request, activityType, completed in
                    request.onComplete(activityType, completed)
                },
                claim: { $0.claim() },
                sourceRect: sourceRect
            )
        )
    }
}

/// A share a view model wants presented: what to share, and what to do once the sheet
/// closes. Hand it to the anchoring view through `.shareSheet(request:)`.
final class ShareRequest {

    let items: [Any]
    /// The activity picked (nil when there was none) and whether it completed.
    let onComplete: (UIActivity.ActivityType?, Bool) -> Void

    private var isClaimed = false

    init(items: [Any], onComplete: @escaping (UIActivity.ActivityType?, Bool) -> Void) {
        self.items = items
        self.onComplete = onComplete
    }

    /// True for the first view that asks, false for any other.
    fileprivate func claim() -> Bool {
        guard !isClaimed else { return false }
        isClaimed = true
        return true
    }
}

/// An invisible view behind the anchoring control: it gives the popover a real view to
/// point at, and a place in the view controller hierarchy to present from.
private struct ShareSheetAnchor<Item>: UIViewRepresentable {

    @Binding var item: Item?
    let activityItems: (Item) -> [Any]
    let onComplete: ((Item, UIActivity.ActivityType?, Bool) -> Void)?
    /// Whether this view gets to present `item`; see `shareSheet(request:)`.
    var claim: (Item) -> Bool = { _ in true }
    /// The part of the anchor the popover points at; the whole anchor when nil.
    var sourceRect: ((CGRect) -> CGRect)? = nil

    final class Coordinator {
        weak var presented: UIActivityViewController?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ anchor: UIView, context: Context) {
        let coordinator = context.coordinator

        if let item, coordinator.presented == nil, claim(item) {
            present(item, from: anchor, coordinator: coordinator)
        } else if item == nil, let presented = coordinator.presented {
            coordinator.presented = nil
            presented.dismiss(animated: true)
        }
    }

    private func present(_ item: Item, from anchor: UIView, coordinator: Coordinator) {
        let binding = $item
        let onComplete = onComplete
        let sourceRect = sourceRect ?? { $0 }
        let controller = UIActivityViewController(activityItems: activityItems(item), applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = anchor
        controller.popoverPresentationController?.sourceRect = sourceRect(anchor.bounds)
        controller.completionWithItemsHandler = { [weak coordinator] activityType, completed, _, _ in
            coordinator?.presented = nil
            binding.wrappedValue = nil
            onComplete?(item, activityType, completed)
        }
        coordinator.presented = controller

        // Not during the update pass: presenting mid-update is unreliable, and the anchor
        // may not have reached its window yet.
        DispatchQueue.main.async {
            guard let presenter = anchor.topMostViewController else {
                coordinator.presented = nil
                binding.wrappedValue = nil
                onComplete?(item, nil, false)
                return
            }
            controller.popoverPresentationController?.sourceRect = sourceRect(anchor.bounds)
            presenter.present(controller, animated: true)
        }
    }
}

private extension UIView {

    /// The controller that owns this view, or whatever it's currently presenting on top —
    /// found through this view's own hierarchy, so it's the right window and scene.
    var topMostViewController: UIViewController? {
        var responder: UIResponder? = self
        while let current = responder, !(current is UIViewController) {
            responder = current.next
        }
        guard var controller = responder as? UIViewController else { return nil }

        while let presented = controller.presentedViewController, !presented.isBeingDismissed {
            controller = presented
        }
        return controller
    }
}
