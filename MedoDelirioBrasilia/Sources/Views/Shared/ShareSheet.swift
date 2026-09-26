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
    func shareSheet<Item>(
        item: Binding<Item?>,
        activityItems: @escaping (Item) -> [Any],
        onComplete: UIActivityViewController.CompletionWithItemsHandler? = nil
    ) -> some View {
        background(
            ShareSheetAnchor(item: item, activityItems: activityItems, onComplete: onComplete)
        )
    }
}

/// An invisible view behind the anchoring control: it gives the popover a real view to
/// point at, and a place in the view controller hierarchy to present from.
private struct ShareSheetAnchor<Item>: UIViewRepresentable {

    @Binding var item: Item?
    let activityItems: (Item) -> [Any]
    let onComplete: UIActivityViewController.CompletionWithItemsHandler?

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

        if let item, coordinator.presented == nil {
            present(activityItems(item), from: anchor, coordinator: coordinator)
        } else if item == nil, let presented = coordinator.presented {
            coordinator.presented = nil
            presented.dismiss(animated: true)
        }
    }

    private func present(_ items: [Any], from anchor: UIView, coordinator: Coordinator) {
        let binding = $item
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = anchor
        controller.popoverPresentationController?.sourceRect = anchor.bounds
        controller.completionWithItemsHandler = { [weak coordinator] activityType, completed, returnedItems, error in
            coordinator?.presented = nil
            binding.wrappedValue = nil
            onComplete?(activityType, completed, returnedItems, error)
        }
        coordinator.presented = controller

        // Not during the update pass: presenting mid-update is unreliable, and the anchor
        // may not have reached its window yet.
        DispatchQueue.main.async {
            guard let presenter = anchor.topMostViewController else {
                coordinator.presented = nil
                binding.wrappedValue = nil
                return
            }
            controller.popoverPresentationController?.sourceRect = anchor.bounds
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
