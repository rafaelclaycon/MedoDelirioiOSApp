//
//  HorizontalAuthorView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 10/12/23.
//

import SwiftUI
import Kingfisher

struct HorizontalAuthorView: View {

    let author: Author
    var compact: Bool = false

    @Environment(\.colorScheme) var colorScheme

    var hasBackgroundImage: Bool {
        author.photo?.isEmpty == false
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.gray)
                .frame(height: 96)
                .opacity(colorScheme == .dark ? 0.25 : 0.15)

            if hasBackgroundImage {
                KFImage(URL(string: author.photo ?? ""))
                    .placeholder {
                        EmptyView()
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(height: 96)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .blur(radius: 200, opaque: false)
            }

            if compact {
                compactContent
            } else {
                fullWidthContent
            }
        }
        .mask {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var fullWidthContent: some View {
        HStack {
            if author.photo?.isEmpty == false {
                KFImage(URL(string: author.photo ?? ""))
                    .placeholder {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .foregroundColor(.gray)
                            .opacity(0.3)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipped()
            }

            VStack(alignment: .leading) {
                Text(author.name)
                    .foregroundColor(.primary)
                    .bold()
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(.leading, author.photo?.isEmpty == false ? 15 : 25)

            Spacer()

            NumberBadgeView(
                number: "\(author.soundCount ?? 0)",
                showBackgroundCircle: true,
                lightModeOpacity: hasBackgroundImage ? 0.5 : 0.2,
                darkModeOpacity: hasBackgroundImage ? 0.25 : 0.5,
                circleColor: hasBackgroundImage ? .white : .gray
            )
            .foregroundColor(.primary)
        }
        .padding(.trailing, 18)
    }

    @ViewBuilder
    private var compactContent: some View {
        VStack(spacing: 6) {
            if hasBackgroundImage {
                KFImage(URL(string: author.photo ?? ""))
                    .placeholder {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    }
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundColor(.gray)
                    .frame(width: 36, height: 36)
            }

            Text(author.name)
                .foregroundColor(.primary)
                .bold()
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview {
    Group {
        // No image
        HorizontalAuthorView(
            author: .init(id: "", name: "Jair Bolsonaro", soundCount: 10)
        )

        // Square image
        HorizontalAuthorView(
            author: .init(
                id: "",
                name: "Samira Close",
                photo: "https://yt3.ggpht.com/ytc/AKedOLRjdzsZyL8rKC0c83BV7_muqPkBtd2TM1kYrV76iA=s900-c-k-c0x00ffffff-no-rj",
                soundCount: 1
            )
        )

        // Image is taller than wider
        HorizontalAuthorView(
            author: .init(
                id: "",
                name: "Abraham Weintraub",
                photo: "https://conteudo.imguol.com.br/c/noticias/fd/2020/06/22/11fev2020---o-entao-ministro-da-educacao-abraham-weintraub-falando-a-comissao-do-senado-sobre-problemas-na-correcao-das-provas-do-enem-1592860563916_v2_3x4.jpg",
                soundCount: 5
            )
        )

        // Image is wider than taller
        HorizontalAuthorView(
            author: .init(
                id: "",
                name: "Biquini",
                photo: "https://conteudo.imguol.com.br/c/entretenimento/10/2019/05/30/integrantes-do-biquini-cavadao-1559247575758_v2_4x3.jpg",
                soundCount: 5
            )
        )

        // URL unavailable
        HorizontalAuthorView(
            author: .init(id: "", name: "Samira Close", photo: "abc", soundCount: 1)
        )
    }
    .padding()
}

#Preview("Compact") {
    VStack {
        HStack(spacing: 12) {
            HorizontalAuthorView(
                author: .init(id: "", name: "Jair Bolsonaro", soundCount: 10),
                compact: true
            )

            HorizontalAuthorView(
                author: .init(
                    id: "",
                    name: "Samira Close",
                    photo: "https://yt3.ggpht.com/ytc/AKedOLRjdzsZyL8rKC0c83BV7_muqPkBtd2TM1kYrV76iA=s900-c-k-c0x00ffffff-no-rj",
                    soundCount: 1
                ),
                compact: true
            )
        }

        HStack(spacing: 12) {
            HorizontalAuthorView(
                author: .init(id: "", name: "Maria Conceição Tavares", soundCount: 10),
                compact: true
            )

            HorizontalAuthorView(
                author: .init(
                    id: "",
                    name: "Samira Close Samira Close Samira",
                    photo: "https://yt3.ggpht.com/ytc/AKedOLRjdzsZyL8rKC0c83BV7_muqPkBtd2TM1kYrV76iA=s900-c-k-c0x00ffffff-no-rj",
                    soundCount: 1
                ),
                compact: true
            )
        }
    }
    .padding()
}
