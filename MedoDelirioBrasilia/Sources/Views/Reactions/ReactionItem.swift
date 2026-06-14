//
//  ReactionItem.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI
import Kingfisher

struct ReactionItem: View {

    let reaction: Reaction

    // MARK: - Computed Properties

    private var itemHeight: CGFloat {
        UIDevice.deviceType == .iPhone ? 100 : 120
    }

    private var reduceTextSize: Bool {
        UIDevice.isSmallDevice && reaction.title.count > 8
    }

    // MARK: - Stored Properties

    @ScaledMetric private var xPinOffset: CGFloat = -7
    @ScaledMetric private var yPinOffset: CGFloat = -10

    // MARK: - View Body

    var body: some View {
        switch reaction.type {
        case .regular:
            RegularReaction(
                title: reaction.title,
                image: URL(string: reaction.image),
                itemHeight: itemHeight,
                reduceTextSize: reduceTextSize
            )

        case .pinnedExisting:
            RegularReaction(
                title: reaction.title,
                image: URL(string: reaction.image),
                itemHeight: itemHeight,
                reduceTextSize: reduceTextSize
            )
            .overlay(alignment: .topLeading) {
                Pin()
                    .offset(x: xPinOffset, y: yPinOffset)
            }

        case .pinnedRemoved:
            RemovedReaction(
                title: reaction.title,
                itemHeight: itemHeight
            )
            .overlay(alignment: .topLeading) {
                Pin()
                    .offset(x: xPinOffset, y: yPinOffset)
            }
        }
    }
}

// MARK: - Subviews

extension ReactionItem {

    struct RegularReaction: View {

        let title: String
        let image: URL?
        let itemHeight: CGFloat
        let reduceTextSize: Bool

        @State private var isLoading: Bool = true

        var body: some View {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .frame(height: itemHeight)
                .background {
                    KFImage(image)
                        .placeholder {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(2)
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 45)
                                    .foregroundColor(.gray)
                            }
                        }
                        .onSuccess { _ in isLoading = false }
                        .onFailure { _ in isLoading = false }
                        .resizable()
                        .scaledToFill()
                        .frame(height: itemHeight)
                }
                .overlay {
                    Text(title)
                        .foregroundColor(.white)
                        .font(reduceTextSize ? .title2 : .title)
                        .bold()
                        .multilineTextAlignment(.center)
                        .shadow(color: .black, radius: 4, y: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    struct Pin: View {

        @ScaledMetric private var size: CGFloat = 12
        @ScaledMetric private var padding: CGFloat = 8

        var body: some View {
            Image(systemName: "pin.fill")
                .scaledToFit()
                .rotationEffect(.degrees(45))
                .foregroundStyle(.white)
                .frame(width: size)
                .padding(.all, padding)
                .background {
                    Circle()
                        .fill(.orange)
                        .shadow(radius: 2, x: 1, y: 1)
                }
        }
    }

    struct RemovedReaction: View {

        let title: String
        let itemHeight: CGFloat

        var body: some View {
            RoundedRectangle(cornerRadius: 20)
                .fill(.clear)
                .frame(height: itemHeight)
                .overlay {
                    Text("Reação '\(title)' Removida")
                        .foregroundColor(.gray)
                        .bold()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.gray, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7]))
                )
        }
    }
}

// MARK: - Preview

#Preview("Pin") {
    ReactionItem.Pin()
        .padding()
}

#Preview("Removed Reaction") {
    HStack(spacing: 20) {
        ReactionItem.RemovedReaction(
            title: Reaction.acidMock.title,
            itemHeight: 100
        )

        ReactionItem.RemovedReaction(
            title: Reaction.enthusiasmMock.title,
            itemHeight: 100
        )
    }
    .padding()
}

#Preview("Reactions List") {

    let columns: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

    return NavigationView {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .listRowSeparatorLeading, spacing: 14) {
                ForEach(Reaction.allMocks) {
                    ReactionItem(reaction: $0)
                }
            }
            .padding()
            .navigationTitle("Reações")
        }
    }
}
