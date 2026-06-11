//
//  AuthorCreditsView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 07/07/25.
//

import SwiftUI

struct AuthorCreditsView: View {

    private let links: [AuthorSectionLink] = [
        AuthorSectionLink(
            name: "Blogue", imageName: "book", link: "https://from-rafael-with-code.ghost.io/", color: .pink, type: .blog
        ),
        AuthorSectionLink(
            name: "Mastodon", imageName: "mastodon", link: "https://burnthis.town/@rafael", color: .purple, type: .socialMedia
        ),
        AuthorSectionLink(
            name: "Bluesky", imageName: "bluesky", link: "https://bsky.app/profile/rafaelschmitt.bsky.social", color: .blue, type: .socialMedia
        )
    ]

    @ScaledMetric private var iconWidth: CGFloat = 20.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sparkles: [PrideSparkle] = PrideSparkle.makeRandom(count: 12)

    private var isPrideMonth: Bool {
        Calendar.current.component(.month, from: .now) == 6
    }

    private var prideGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .orange, .yellow, .green, .blue, .purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .center, spacing: .spacing(.large)) {
            VStack(spacing: .spacing(.xSmall)) {
                Text("Criado por Rafael Schmitt")
                    .font(.system(.headline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isPrideMonth ? AnyShapeStyle(prideGradient) : AnyShapeStyle(.foreground))

                if isPrideMonth {
                    Text("Feito com orgulho 🏳️‍🌈")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .overlay {
                if isPrideMonth, !reduceMotion {
                    PrideSparklesView(sparkles: sparkles)
                }
            }

            HStack(spacing: .spacing(.medium)) {
                Spacer()

                ForEach(links) { link in
                    Button {
                        Task {
                            OpenUtility.open(link: link.link)

                            switch link.type {
                            case .blog:
                                await sendAnalytics(for: "didTapBlogLink")
                            case .socialMedia:
                                await sendAnalytics(for: "didTapSocialLink(\(link.name))")
                            }
                        }
                    } label: {
                        if link.type == .blog {
                            Image(systemName: link.imageName)
                                .bold()
                                .foregroundColor(link.color)
                        } else {
                            Image(link.imageName)
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconWidth)
                                .foregroundColor(link.color)
                        }
                    }
                    .borderedButton(colored: link.color)
                }

                Spacer()
            }
        }
    }

    private func sendAnalytics(for action: String) async {
        await AnalyticsService().send(
            originatingScreen: "SettingsView",
            action: action
        )
    }
}

private struct PrideSparkle: Identifiable {

    let id = UUID()
    let relativePosition: CGPoint
    let size: CGFloat
    let color: Color
    let delay: Double

    static func makeRandom(count: Int) -> [PrideSparkle] {
        let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
        return (0..<count).map { index in
            PrideSparkle(
                relativePosition: CGPoint(x: .random(in: -0.05...1.05), y: .random(in: -0.3...1.3)),
                size: .random(in: 8...16),
                color: colors[index % colors.count],
                delay: .random(in: 0...0.8)
            )
        }
    }
}

private struct PrideSparklesView: View {

    let sparkles: [PrideSparkle]

    var body: some View {
        GeometryReader { geometry in
            ForEach(sparkles) { sparkle in
                SingleSparkleView(sparkle: sparkle)
                    .position(
                        x: geometry.size.width * sparkle.relativePosition.x,
                        y: geometry.size.height * sparkle.relativePosition.y
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SingleSparkleView: View {

    let sparkle: PrideSparkle

    @State private var isVisible = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: sparkle.size))
            .foregroundStyle(sparkle.color)
            .scaleEffect(isVisible ? 1.0 : 0.1)
            .rotationEffect(.degrees(isVisible ? 0 : -60))
            .opacity(isVisible ? 1.0 : 0.0)
            .task {
                try? await Task.sleep(for: .seconds(sparkle.delay))
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                    isVisible = true
                }
                try? await Task.sleep(for: .seconds(0.7))
                withAnimation(.easeOut(duration: 0.5)) {
                    isVisible = false
                }
            }
    }
}

#Preview {
    Form {
        Section {
            AuthorCreditsView()
        }
    }
}
