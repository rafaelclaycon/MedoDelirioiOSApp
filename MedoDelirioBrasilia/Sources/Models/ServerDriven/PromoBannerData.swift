//
//  PromoBannerData.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/08/26.
//

import Foundation

/// A fully server-driven promotional banner: image, copy, call to action and colors
/// all come from the API so a campaign can be launched, tweaked and ended without
/// shipping a new build.
///
/// Everything but `enabled` is optional on purpose — turning the campaign off should be
/// as simple as serving `{"enabled": false}`, with no dummy payload to keep around.
/// `BannerRepository.promoBanner()` is what guarantees the pieces the banner can't
/// render without are actually there.
struct PromoBannerData: Codable {

    let enabled: Bool
    let imageUrl: String?
    let imageAccessibilityLabel: String?
    let text: [String]?
    let buttonTitle: String?
    let buttonUrl: String?
    /// RGB, ARGB or shorthand hex, with or without the leading `#`. See `Color(hex:)`.
    let backgroundColorHex: String?
    let foregroundColorHex: String?
    /// Version to hide the banner from — usually whatever is sitting in App Review,
    /// so an unannounced campaign doesn't leak to a reviewer. Same idea as
    /// `AnniversaryBannerData.excludedVersion`.
    let excludedVersion: String?

    var imageURL: URL? {
        guard let imageUrl, !imageUrl.isEmpty else { return nil }
        return URL(string: imageUrl)
    }

    var buttonURL: URL? {
        guard let buttonUrl, !buttonUrl.isEmpty else { return nil }
        return URL(string: buttonUrl)
    }

    var paragraphs: [String] {
        text ?? []
    }
}
