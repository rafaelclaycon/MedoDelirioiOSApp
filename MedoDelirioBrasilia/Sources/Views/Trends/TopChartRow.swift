//
//  TopChartRow.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 29/05/22.
//

import SwiftUI

enum TopChartPlace {

    case first, second, third, other
}

struct TopChartRow: View {

    let item: TopChartItem

    private var isEven: Bool {
        if let idAsInt = Int(item.rankNumber), idAsInt.isMultiple(of: 2) {
            return true
        } else {
            return false
        }
    }
    
    private var cellFill: Color {
        if isEven {
            return .gray
        } else {
            return .clear
        }
    }

    private var showStripedList: Bool {
        UIDevice.deviceType == .mac
    }

    private var isSpecialCase: Bool {
        ["1","2","3"].contains(item.rankNumber)
    }

    private var place: TopChartPlace {
        switch item.rankNumber {
        case "1": return .first
        case "2": return .second
        case "3": return .third
        default: return .other
        }
    }

    // MARK: - View Body

    var body: some View {
        if isSpecialCase {
            SpecialRow(item: item, place: place)
        } else {
            HStack(spacing: 15) {
                NumberBadgeView(number: item.rankNumber, showBackgroundCircle: !showStripedList)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.contentName)
                        .bold()
                    Text(item.contentAuthorName)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(item.shareCount)")
            }
            .padding(.leading, 10)
            .padding(.trailing)
            .padding(.vertical, 8)
            .overlay {
                if showStripedList {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(cellFill)
                        .opacity(0.2)
                }
            }
        }
    }
}

// MARK: - Subviews

extension TopChartRow {

    private struct SpecialRow: View {

        let item: TopChartItem
        let place: TopChartPlace

        private let emojiSize: CGFloat = 52

        private var background: Color {
            if place == .first {
                return .yellow
            } else if place == .second {
                return .gray
            } else {
                return .orange
            }
        }

        private var border: Color {
            if place == .first {
                return .yellow
            } else if place == .second {
                return .gray
            } else {
                return .orange
            }
        }

        // MARK: - View Body

        var body: some View {
            if #available(iOS 26, *) {
                content()
                    .glassEffect(
                        .regular.tint(
                            background.opacity(0.4)
                        ).interactive(),
                        in: .rect(cornerRadius: .spacing(.large))
                    )
                    .scrollClipDisabled()
            } else {
                content()
                    .background {
                        RoundedRectangle(cornerRadius: 23)
                            .fill(background)
                            .opacity(0.2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 23, style: .continuous)
                                    .stroke(border.opacity(0.7), lineWidth: 1)
                            )
                    }
            }
        }

        func content() -> some View {
            HStack(spacing: .spacing(.xxSmall)) {
                switch place {
                case .first:
                    Text("🥇")
                        .font(.system(size: emojiSize))
                case .second:
                    Text("🥈")
                        .font(.system(size: emojiSize))
                case .third:
                    Text("🥉")
                        .font(.system(size: emojiSize))
                case .other:
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: .spacing(.xxSmall)) {
                    Text(item.contentName)
                        .bold()
                    Text(item.contentAuthorName)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text("\(item.shareCount)")
                    .font(place == .first ? .title3 : .body)
                    .bold(place == .first)
            }
            .padding(.vertical, 8)
            .padding(.trailing, 20)
            .padding(.leading, 12)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 10) {
        TopChartRow(item: TopChartItem(
            id: "ABCD-EFGH",
            rankNumber: "1",
            contentId: "ABC",
            contentName: "GRANDE DIA (Pavarotti)",
            contentAuthorId: "DEF",
            contentAuthorName: "Bolsonaro",
            shareCount: 3
        ))

        TopChartRow(item: TopChartItem(
            id: "ABCD-EFGH",
            rankNumber: "2",
            contentId: "ABC",
            contentName: "Tu quer o cu e ainda quer raspado",
            contentAuthorId: "DEF",
            contentAuthorName: "Samanta Alves",
            shareCount: 2
        ))

        TopChartRow(item: TopChartItem(
            id: "ABCD-EFGH",
            rankNumber: "3",
            contentId: "ABC",
            contentName: "Ihuuu (compilação)",
            contentAuthorId: "DEF",
            contentAuthorName: "Jair Bolsonaro",
            shareCount: 2
        ))

        TopChartRow(item: TopChartItem(
            id: "ABCD-EFGH",
            rankNumber: "4",
            contentId: "ABC",
            contentName: "Ai eu me sinto o Pikachu",
            contentAuthorId: "DEF",
            contentAuthorName: "Fernanda Torres",
            shareCount: 2
        ))

        TopChartRow(item: TopChartItem(
            id: "ABCD-EFGH",
            rankNumber: "5",
            contentId: "ABC",
            contentName: "Amontoado de coisa escrita",
            contentAuthorId: "DEF",
            contentAuthorName: "Jair Bolsonaro",
            shareCount: 1
        ))
    }
    .padding(.horizontal, 14)
}
