//
//  ContentModePicker.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 29/03/25.
//

import SwiftUI

struct ContentModePicker<Option: FilterOption>: View {

    let options: [Option]
    @Binding var selected: Option
    let allowScrolling: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: .spacing(.small)) {
                    scrollingOptions()
                }
            } else {
                scrollingOptions()
            }
        }
        .scrollDisabled(!allowScrolling)
    }

    func scrollingOptions() -> some View {
        HStack(spacing: .spacing(.small)) {
            ForEach(options) { option in
                PillView(
                    option: option,
                    selected: selected
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selected = option
                    }
                }
                .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: selected)
            }
        }
        .padding(.horizontal)
        .padding(.top, .spacing(.xSmall))
        .padding(.bottom, .spacing(.xxSmall))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - Subviews

extension ContentModePicker {

    private struct PillView: View {

        let option: Option
        let selected: Option

        @Environment(\.colorScheme) private var colorScheme

        // MARK: - Computed Properties

        private var selectedTextColor: Color {
            switch colorScheme {
            case .light:
                if #available(iOS 26, *) {
                    Color.primary
                } else {
                    Color.whatsAppDarkGreen
                }
            case .dark:
                Color.green
            @unknown default:
                Color.white
            }
        }

        private var notSelectedTextColor: Color {
            switch colorScheme {
            case .light:
                Color.black.opacity(0.6)
            case .dark:
                Color.white.opacity(0.6)
            @unknown default:
                Color.black.opacity(0.6)
            }
        }

        private var selectedBackgroundColor: Color {
            switch colorScheme {
            case .light:
                if #available(iOS 26, *) {
                    Color.green.opacity(0.5)
                } else {
                    Color.whatsAppLightGreen
                }
            case .dark:
                Color.green.opacity(0.3)
            @unknown default:
                Color.gray.opacity(0.15)
            }
        }

        private var notSelectedBackgroundColor: Color {
            switch colorScheme {
            case .light:
                Color.gray.opacity(0.1)
            case .dark:
                Color.gray.opacity(0.3)
            @unknown default:
                Color.gray.opacity(0.15)
            }
        }

        // MARK: - Dynamic Type

        @ScaledMetric private var verticalPadding: CGFloat = .spacing(.xSmall)
        @ScaledMetric private var horizontalPadding: CGFloat = .spacing(.medium)

        // MARK: - View Body

        var body: some View {
            if #available(iOS 26, *) {
                Group {
                    if option == selected {
                        Text(option.displayName)
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    } else {
                        Image(systemName: option.symbol)
                            .padding(.horizontal, .spacing(.xSmall))
                            .transition(.scale(scale: 0.5).combined(with: .opacity))
                    }
                }
                .foregroundStyle(
                    option == selected ? selectedTextColor : .primary
                )
                .font(.callout)
                .fontWeight(option == selected ? .bold : .regular)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .glassEffect(
                    .regular.tint(
                        option == selected ? selectedBackgroundColor : nil
                    ).interactive()
                )
            } else {
                Text(option.displayName)
                    .foregroundStyle(
                        option == selected ? selectedTextColor : notSelectedTextColor
                    )
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, horizontalPadding)
                    .background {
                        RoundedRectangle(cornerRadius: .spacing(.huge))
                            .fill(
                                option == selected ? selectedBackgroundColor : notSelectedBackgroundColor
                            )
                    }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selected: ContentModeOption = .all

    ContentModePicker(
        options: ContentModeOption.allCases,
        selected: $selected,
        allowScrolling: true
    )
}
