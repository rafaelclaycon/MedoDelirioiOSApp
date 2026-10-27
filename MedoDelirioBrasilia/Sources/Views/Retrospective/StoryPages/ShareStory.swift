//
//  ShareStory.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/25.
//

import SwiftUI
import Kingfisher

/// The last page: the picture that gets shared, shown as it is, and the button to share it.
struct ShareStory: View {

    let year: Int
    let topAuthor: TopAuthorItem?
    let topSounds: [TopChartItem]
    let totalShares: Int
    let favoriteDay: String
    let secondsListened: Double
    let topEpisodeTitle: String?
    let onShareTapped: (() -> Void)?

    @State private var showContent = false
    @State private var shareableImage: UIImage?
    @State private var imageGenerationFailed = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 50)

            Text("Esse foi o seu \(String(year))")
                .font(.system(size: 34, weight: .heavy))
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            Group {
                if let shareableImage {
                    Image(uiImage: shareableImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                        .accessibilityLabel("Prévia da imagem da sua Retrospectiva")
                } else if imageGenerationFailed {
                    Text("Não foi possível gerar a imagem")
                        .font(.callout)
                        .opacity(0.7)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxHeight: .infinity)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.92)

            if let shareableImage {
                let image = Image(uiImage: shareableImage)
                ShareLink(
                    item: image,
                    preview: SharePreview("Minha Retrospectiva \(String(year))", image: image)
                ) {
                    Label("Compartilhar", systemImage: "square.and.arrow.up")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(RetroPalette.deepRed)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(.white))
                }
                .simultaneousGesture(TapGesture().onEnded { _ in
                    onShareTapped?()
                })
            }

            Spacer(minLength: 60)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                showContent = true
            }
        }
        .task {
            await generateShareableImage()
        }
    }

    // MARK: - Image Generation

    /// The author's photo is downloaded first: `ImageRenderer` draws only what's on hand.
    private func generateShareableImage() async {
        var authorImage: UIImage? = nil
        if let photoURLString = topAuthor?.authorPhoto, let photoURL = URL(string: photoURLString) {
            authorImage = try? await KingfisherManager.shared.retrieveImage(with: photoURL).image
        }

        let shareCard = ShareableRetroImageView(
            year: year,
            authorPhoto: authorImage,
            authorName: topAuthor?.authorName,
            topSounds: topSounds,
            totalShares: totalShares,
            favoriteDay: favoriteDay,
            secondsListened: secondsListened,
            topEpisodeTitle: topEpisodeTitle
        )

        if let uiImage = shareCard.generateImage() {
            withAnimation {
                shareableImage = uiImage
            }
        } else {
            imageGenerationFailed = true
        }
    }
}

#Preview {
    ShareStory(
        year: 2026,
        topAuthor: nil,
        topSounds: [],
        totalShares: 68,
        favoriteDay: "Sexta-feira",
        secondsListened: 36_000,
        topEpisodeTitle: "Um episódio de exemplo",
        onShareTapped: nil
    )
    .background(
        LinearGradient(
            colors: [RetroPalette.shareTop, RetroPalette.shareBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
