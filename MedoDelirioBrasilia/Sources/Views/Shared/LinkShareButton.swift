//
//  LinkShareButton.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/09/26.
//

import CoreTransferable
import SwiftUI
import UIKit

/// A share button for a link, with the preview the share sheet shows at its top.
///
/// Use it for share buttons in a toolbar. It's a plain `ShareLink`, so the toolbar keeps
/// it a native bar button and the system anchors the share sheet to it, including the
/// Liquid Glass morph into a popover at regular width. `.shareSheet(item:)` puts a UIKit
/// view inside the item, which turned it into a custom-view item that glitched on the
/// unfolded iPhone Duo (the sheet grew from an orb; the button jumped as its label
/// changed). Outside toolbars `.shareSheet(item:)` is fine, and it can also hand apps
/// like Messages our own link preview, which `ShareLink` can't.
///
/// The preview image is loaded ahead of time (`loadImage(from:)`, from the screen's
/// `.task`), so tapping shares straight away. Until it arrives the preview uses
/// `placeholderSymbol`; the button stays the same view either way, so the toolbar
/// never rebuilds it.
///
/// `ShareLink` has no tap or completion callback, so there's no "before" to hang
/// analytics on. `onShared` runs instead when an app actually takes the link — after a
/// destination (Messages, Copiar, …) is picked, not when the button is tapped. It can run
/// more than once if the same sheet shares to several destinations, and off the main
/// thread.
struct LinkShareButton: View {

    let url: URL
    let title: String
    let image: Image?
    var placeholderSymbol: String = "link"
    var accessibilityLabel: LocalizedStringKey = "Compartilhar"
    var onShared: @Sendable () -> Void = {}

    var body: some View {
        ShareLink(
            item: SharedLink(url: url, onExport: onShared),
            preview: SharePreview(title, image: image ?? Image(systemName: placeholderSymbol))
        ) {
            Label(accessibilityLabel, systemImage: "square.and.arrow.up")
        }
    }

    /// Downloads the preview image, or nil when there's none or it fails to load.
    static func loadImage(from url: URL?) async -> Image? {
        guard let url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
}

/// The URL, handed over only when the receiving app asks for it — which is how
/// `LinkShareButton` learns a share happened.
private struct SharedLink: Transferable {

    let url: URL
    let onExport: @Sendable () -> Void

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation { link in
            link.onExport()
            return link.url
        }
    }
}
