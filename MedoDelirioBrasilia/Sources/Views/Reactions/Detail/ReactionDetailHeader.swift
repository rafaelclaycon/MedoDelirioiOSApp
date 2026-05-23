//
//  ReactionDetailHeader.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 02/05/24.
//

import SwiftUI
import Kingfisher

struct ReactionDetailHeader: View {

    let title: String
    let subtitle: String
    let imageUrl: String
    let attributionText: String?
    let attributionURL: URL?

    @ScaledMetric(relativeTo: .caption) private var attURLSymbolWidth: CGFloat = 12

    @State private var showImageCredits = false

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

            HStack {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 6, x: 1, y: 2)

                Spacer()

                if attributionText != nil, attributionURL != nil {
                    Button {
                        showImageCredits.toggle()
                    } label: {
                        Text("📸 ")
                            .font(.body)
                            .bold()
                            .shadow(color: .black, radius: 6, x: 1, y: 2)
                    }
                }
            }
            .padding([.top, .leading, .trailing], 22)
            .padding(.bottom, attributionText != nil ? 12 : 22)
        }
        .overlay {
            Text(title)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 4, x: 2, y: 2)
        }
        .background {
            if #available(iOS 26.0, *) {
                image
                    .backgroundExtensionEffect()
            } else {
                image
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .alert(
            "Créditos da Imagem",
            isPresented: $showImageCredits,
            actions: {
                Button("Visitar Fonte") {
                    OpenUtility.open(attributionURL!)
                }

                Button("Fechar", role: .cancel) {
                    showImageCredits.toggle()
                }
            },
            message: {
                Text(attributionText ?? "")
            }
        )
    }

    var image: some View {
        KFImage(URL(string: imageUrl))
            .placeholder {
                Image(systemName: "photo.on.rectangle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .foregroundColor(.gray)
                    .opacity(0.3)
            }
            .resizable()
            .scaledToFill()
            .overlay(Color.black.opacity(0.3))
            .blur(radius: 1)
            .scaleEffect(1.05)
            .frame(height: 260)
            //.frame(width: headerPhotoGeometry.size.width, height: self.getHeightForHeaderImage(headerPhotoGeometry))
            .clipped()
    }
}

#Preview {
    VStack {
        ReactionDetailHeader(
            title: "deboche",
            subtitle: "20 itens. Atualizada há 1 ano.",
            imageUrl: Reaction.acidMock.image,
            attributionText: "GABRIELA BILÓ EM INSTAGRAM.",
            attributionURL: URL(string: "https://www.instagram.com/gabriela.bilo")!
        )
        .frame(height: 260)

        Spacer()
    }
    .ignoresSafeArea()
}
