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
/// advertised, not like the app. The server decides when it shows up and when it goes away,
/// so it can't be dismissed — but it can be collapsed down to just the logo, which gives
/// back most of the screen without costing the campaign its brand impression.
struct PromoBanner: View {

    let bannerData: PromoBannerData

    /// Grows with Dynamic Type so the logo doesn't shrink into insignificance next to
    /// text at the largest sizes.
    @ScaledMetric(relativeTo: .callout) private var imageHeight: CGFloat = 52

    /// A campaign that outlives its image shouldn't show a broken-image placeholder —
    /// the copy and the button stand on their own.
    @State private var imageDidFail: Bool = false

    @State private var isCollapsed: Bool

    /// The collapsed state is the logo, so there has to be a logo. Without one there is
    /// nothing left to collapse *to*, and the banner stays expanded with no chevron.
    private var canCollapse: Bool {
        !imageDidFail && bannerData.imageURL != nil
    }

    /// Guards against the image failing *after* the user collapsed, which would otherwise
    /// leave an empty colored bar behind.
    private var showsDetails: Bool {
        !isCollapsed || !canCollapse
    }

    // MARK: - Initializer

    /// A campaign is only ever collapsed because the user collapsed *that* campaign, so a
    /// banner the user hasn't seen before always starts expanded.
    init(bannerData: PromoBannerData) {
        self.bannerData = bannerData
        _isCollapsed = State(
            initialValue: AppPersistentMemory.shared.collapsedPromoBannerId() == bannerData.identity
        )
    }

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
                    // The logo is the one centered element — it reads as a masthead over the
                    // left-aligned copy. The inset keeps a wide wordmark clear of the chevron
                    // while staying optically centered.
                    .padding(.horizontal, .spacing(.xLarge))
                    .accessibilityLabel(imageAccessibilityLabel)
                    .accessibilityHidden(imageAccessibilityLabel.isEmpty)
                    .contentShape(Rectangle())
                    // The logo *is* the collapsed state, so it doubles as the way back out
                    // of it. Sighted convenience only — VoiceOver gets the labelled chevron.
                    .onTapGesture { toggleCollapsed() }
                    .overlay(alignment: .trailing) {
                        collapseToggle
                            // Reaches back out through the card's own padding so the chevron
                            // sits in the corner, while `.trailing` keeps it centered on the
                            // logo however tall Dynamic Type makes it.
                            .padding(.trailing, -CGFloat.spacing(.large))
                    }
            }

            if showsDetails {
                VStack(alignment: .leading, spacing: .spacing(.xSmall)) {
                    ForEach(bannerData.paragraphs, id: \.self) { paragraph in
                        Text(markedDownText(paragraph))
                            .font(.callout)
                            .foregroundStyle(foregroundColor)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .padding(.top, .spacing(.xSmall))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.top, .horizontal], .spacing(.large))
        // Collapsed, the card is just the logo, so it wants even padding to read as a pill.
        .padding(.bottom, showsDetails ? .spacing(.medium) : .spacing(.large))
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(backgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    // MARK: - Subviews

    private var collapseToggle: some View {
        Button {
            toggleCollapsed()
        } label: {
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.bold))
                .foregroundStyle(foregroundColor)
                .rotationEffect(.degrees(isCollapsed ? 0 : 180))
                // A 44pt square keeps the tap target honest without padding math against
                // the card's own insets.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(isCollapsed ? "Expandir o anúncio" : "Recolher o anúncio")
    }

    // MARK: - Functions

    private func toggleCollapsed() {
        guard canCollapse else { return }
        withAnimation(.snappy(duration: 0.25)) {
            isCollapsed.toggle()
        }
        AppPersistentMemory.shared.setCollapsedPromoBannerId(
            to: isCollapsed ? bannerData.identity : nil
        )
    }

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
/// the network, so with the placeholder URL below the image simply doesn't render. With a
/// real URL in place, tap the chevron to check the collapsed state and the transition.
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
