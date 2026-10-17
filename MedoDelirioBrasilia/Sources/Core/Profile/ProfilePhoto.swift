//
//  ProfilePhoto.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import UIKit

/// The user's own profile photo, kept small: it syncs through iCloud key-value storage,
/// whose 1 MB is shared with the favorites and episode state. 256 px is still sharp at
/// the largest it's drawn (the shared picture's avatar, 168 px at 3x).
enum ProfilePhoto {

    static let side: CGFloat = 256
    /// Well over what a 256 px JPEG at this quality takes (20 to 40 KB), as a guard.
    static let maxBytes = 150_000
    static let compressionQuality: CGFloat = 0.8

    /// A square JPEG of `side` points at scale 1, from an image already cropped square.
    static func thumbnailData(from image: UIImage) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: side, height: side)
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = resized.jpegData(compressionQuality: compressionQuality), data.count <= maxBytes else {
            return nil
        }
        return data
    }
}
