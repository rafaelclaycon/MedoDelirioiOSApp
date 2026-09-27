//
//  ExternalLinkButton.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 26/03/24.
//

import SwiftUI
import Kingfisher

struct ExternalLinkButton: View {

    let externalLink: ExternalLink
    /// Icon only when there's no room for the name; VoiceOver still reads it.
    var showsTitle = true

    var imageUrl: URL {
        URL(string: "\(APIConfig.baseServerURL)images/\(externalLink.symbol)")!
    }

    var body: some View {
        Button {
            OpenUtility.open(link: externalLink.link)
        } label: {
            HStack(spacing: 10) {
                KFImage(imageUrl)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22)

                if showsTitle {
                    Text(externalLink.title)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, showsTitle ? 6 : 2)
        }
        .capsule(colored: externalLink.color.toColor())
        .accessibilityLabel(externalLink.title)
    }
}

#Preview {
    ExternalLinkButton(
        externalLink: .init(
            symbol: "youtube-full-color.png",
            title: "YouTube",
            color: "red",
            link: "https://www.youtube.com/@CasimiroMiguel"
        )
    )
}
