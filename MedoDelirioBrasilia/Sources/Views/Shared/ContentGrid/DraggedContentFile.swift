//
//  DraggedContentFile.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/09/26.
//

import CoreTransferable
import UniformTypeIdentifiers

/// A sound or song dragged out of a content grid, e.g. into WhatsApp beside the app on
/// iPad or on the unfolded iPhone Duo.
///
/// The receiving app gets the MP3 named after the content's title. It's handed over only
/// when that app accepts the drop, which is when `onExport` runs — a drag that is
/// cancelled or dropped nowhere never calls it. It runs off the main thread.
///
/// The MP3 goes out as data, not as a file. With a `FileRepresentation`, apps that read
/// drops through the older `NSItemProvider.loadItem(forTypeIdentifier:)` get back a
/// temporary file URL instead of the audio, and WhatsApp pasted that URL into the chat as
/// text. Apps that ask for a file (`loadFileRepresentation`) still get one, named with
/// `suggestedFileName`. Sounds and songs are small enough to read into memory.
struct DraggedContentFile: Transferable {

    /// `nil` when the file couldn't be found; the drop then fails instead of the drag.
    let url: URL?
    let title: String
    let onExport: @Sendable () -> Void

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .mp3) { file in
            guard let url = file.url else {
                throw CocoaError(.fileNoSuchFile)
            }
            let data = try Data(contentsOf: url)
            file.onExport()
            return data
        }
        .suggestedFileName { $0.fileName }
    }

    private var fileName: String {
        // "/" and ":" aren't allowed in file names.
        let name = title.replacingOccurrences(of: "[/:]", with: "-", options: .regularExpression)
        return "\(name).mp3"
    }
}
