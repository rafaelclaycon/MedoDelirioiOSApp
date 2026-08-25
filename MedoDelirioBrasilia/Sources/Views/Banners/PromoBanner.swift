//
//  PromoBanner.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 25/08/26.
//

import Kingfisher
import SwiftUI

/// A fully server-driven "ad" for whatever the podcast is promoting at the moment —
/// image, copy, link and colors all arrive from the API (see `PromoBannerData`).
///
/// Unlike the tip-style banners on this screen, it paints a solid brand color in both
/// color schemes, the way `DunBannerView` does: the point is to look like the thing being
/// advertised, not like the app. It is also not dismissible — the server decides when it
/// shows up and when it goes away.
struct PromoBanner: View {

    let bannerData: PromoBannerData

    /// Grows with Dynamic Type so the logo doesn't shrink into insignificance next to
    /// text at the largest sizes.
    @ScaledMetric(relativeTo: .callout) private var imageHeight: CGFloat = 52

    /// A campaign that outlives its image shouldn't show a broken-image placeholder —
    /// the copy and the button stand on their own.
    @State private var imageDidFail: Bool = false

    // MARK: - Computed Properties

    private var backgroundColor: Color {
        guard let hex = bannerData.backgroundColorHex, !hex.isEmpty else { return .promoDarkGreen }
        return Color(hex: hex)
    }

    private var foregroundColor: Color {
        guard let hex = bannerData.foregroundColorHex, !hex.isEmpty else { return .white }
        return Color(hex: hex)
    }

    private var imageAccessibilityLabel: String {
        bannerData.imageAccessibilityLabel ?? ""
    }

    // MARK: - View Body

    var body: some View {
        VStack(alignment: .leading, spacing: .spacing(.small)) {
            if !imageDidFail, let imageURL = bannerData.imageURL {
                KFImage(imageURL)
                    .placeholder {
                        ProgressView()
                            .tint(foregroundColor)
                            .frame(height: imageHeight)
                    }
                    .onFailure { _ in imageDidFail = true }
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: imageHeight)
                    .accessibilityLabel(imageAccessibilityLabel)
                    .accessibilityHidden(imageAccessibilityLabel.isEmpty)
            }

            VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                ForEach(bannerData.paragraphs, id: \.self) { paragraph in
                    Text(markedDownText(paragraph))
                        .font(.callout)
                        .foregroundStyle(foregroundColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button {
                onButtonSelected()
            } label: {
                Text(bannerData.buttonTitle ?? "")
                    .bold()
                    .foregroundStyle(backgroundColor)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, .spacing(.xSmall))
                    .padding(.vertical, .spacing(.nano))
            }
            .tint(foregroundColor)
            .controlSize(.regular)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .padding(.top, .spacing(.xxxSmall))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.top, .horizontal], .spacing(.large))
        .padding(.bottom, .spacing(.medium))
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(backgroundColor)
        }
    }

    // MARK: - Functions

    /// Falls back to the raw text instead of an empty string, so a malformed asterisk
    /// on the server can't blank out a whole paragraph.
    private func markedDownText(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private func onButtonSelected() {
        Task {
            await AnalyticsService().send(
                originatingScreen: "PromoBanner",
                action: "didTapPromoBannerButton"
            )
        }
        guard let buttonURL = bannerData.buttonURL else { return }
        OpenUtility.open(buttonURL)
    }
}

// MARK: - Preview

/// Swap in a reachable `imageUrl` to see the logo — the preview canvas loads it over
/// the network, so with the placeholder URL below the image simply doesn't render.
#Preview("Full") {
    PromoBanner(
        bannerData: PromoBannerData(
            enabled: true,
            imageUrl: "https://example.com/promo-logo.png",
            imageAccessibilityLabel: "Logo do Lorem Ipsum Fest",
            text: [
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                "Sed do eiusmod **tempor** incididunt ut labore et dolore magna aliqua."
            ],
            buttonTitle: "Saiba mais",
            buttonUrl: "https://example.com",
            backgroundColorHex: "0B3B24",
            foregroundColorHex: "FFFFFF",
            excludedVersion: nil
        )
    )
    .padding(.horizontal, .spacing(.medium))
}

#Preview("No Image, Default Colors") {
    PromoBanner(
        bannerData: PromoBannerData(
            enabled: true,
            imageUrl: nil,
            imageAccessibilityLabel: nil,
            text: [
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore."
            ],
            buttonTitle: "Saiba mais",
            buttonUrl: "https://example.com",
            backgroundColorHex: nil,
            foregroundColorHex: nil,
            excludedVersion: nil
        )
    )
    .padding(.horizontal, .spacing(.medium))
}
