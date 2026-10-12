//
//  YouHeaderView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// The hero at the top of Você: avatar, nickname and "Com a gente desde" over a
/// slowly drifting green mesh that runs up under the status bar and fades into the
/// page at the bottom.
struct YouHeaderView: View {

    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var avatarAuthor: Author?

    /// How far the green reaches above the hero: under the bars, and into a pull-down
    /// so overscrolling never shows a gap.
    private static let upwardReach: CGFloat = 600
    /// The stretch below the hero where the green fades into the page.
    private static let fadeHeight: CGFloat = 72

    private var memberSinceText: String {
        guard let memberSince = profileStore.memberSince else {
            return "Que bom ter você aqui"
        }
        let monthAndYear = memberSince.formatted(
            .dateTime.month(.wide).year().locale(Locale(identifier: "pt_BR"))
        )
        return "Com a gente desde \(monthAndYear)"
    }

    var body: some View {
        VStack(spacing: .spacing(.small)) {
            avatar

            Text(profileStore.nickname ?? "Escolha um apelido")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .foregroundStyle(.white.opacity(profileStore.nickname == nil ? 0.75 : 1))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)

            badge
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .spacing(.large))
        .padding(.bottom, .spacing(.small))
        .background(alignment: .bottom) {
            // Masked before the negative padding, so the mask covers the whole reach
            // and not just the hero's own height. The fade hangs below the hero, behind
            // the cards that follow, so it doesn't push them down.
            HeroBackground(fadeHeight: Self.fadeHeight)
                .mask(alignment: .bottom) {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: Self.fadeHeight)
                    }
                }
                .padding(.top, -Self.upwardReach)
                .padding(.bottom, -Self.fadeHeight)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edita a foto e o apelido.")
        .task(id: profileStore.avatarAuthorID) {
            avatarAuthor = profileStore.avatarAuthorID.flatMap { try? LocalDatabase.shared.author(withId: $0) }
        }
    }

    // MARK: - Subviews

    private var avatar: some View {
        ProfileAvatarView(photo: avatarAuthor?.photo, size: 92)
            .background(Circle().fill(.white.opacity(0.25)))
            .overlay {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
            }
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "pencil")
                    .font(.footnote.bold())
                    .foregroundStyle(Color.darkestGreen)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                    .offset(x: 2, y: 2)
            }
    }

    /// The symbol sits inline with the text, so the whole thing centers, also when it
    /// wraps at large text sizes.
    ///
    /// In light mode the glass turns pale over the green, so white text washes out there.
    private var badge: some View {
        Text("\(Image(systemName: profileStore.memberSince == nil ? "hand.wave.fill" : "heart.fill"))  \(memberSinceText)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(colorScheme == .light ? Color.primary : .white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, .spacing(.medium))
            .padding(.vertical, .spacing(.xSmall))
            .glassEffect(.regular.tint(.white.opacity(0.12)), in: .capsule)
    }
}

// MARK: - Background

extension YouHeaderView {

    /// Deep greens with a streak of bright green and a touch of yellow, drifting slowly.
    /// Holds still with Reduce Motion.
    struct HeroBackground: View {

        /// Keeps the speech bubble out of the fade, where it would vanish.
        let fadeHeight: CGFloat

        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private static let deepGreen = Color(red: 0.01, green: 0.24, blue: 0.11)
        private static let teal = Color(red: 0.00, green: 0.47, blue: 0.40)

        private static let colors: [Color] = [
            deepGreen, .darkerGreen, .brightGreen,
            teal, .brightGreen, .brightYellow,
            .darkestGreen, deepGreen, teal
        ]

        var body: some View {
            ZStack(alignment: .bottomTrailing) {
                if reduceMotion {
                    mesh(at: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                        mesh(at: context.date.timeIntervalSinceReferenceDate)
                    }
                }

                // A soft light from the left, so the green reads as lit rather than flat.
                RadialGradient(
                    colors: [.white.opacity(0.28), .clear],
                    center: UnitPoint(x: 0.05, y: 0.6),
                    startRadius: 0,
                    endRadius: 320
                )
                .blendMode(.softLight)

                Image(systemName: "quote.bubble.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .foregroundStyle(.white.opacity(0.07))
                    .rotationEffect(.degrees(-14))
                    .offset(x: 50, y: -fadeHeight)
                    .accessibilityHidden(true)
            }
            .clipped()
        }

        private func mesh(at time: TimeInterval) -> some View {
            let t = Float(time)
            let drift = { (speed: Float, phase: Float, amount: Float) in
                sin(t * speed + phase) * amount
            }

            return MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5 + drift(0.35, 0, 0.12), 0], [1, 0],
                    [0, 0.5 + drift(0.3, 1, 0.1)],
                    [0.5 + drift(0.4, 2, 0.15), 0.5 + drift(0.33, 3, 0.15)],
                    [1, 0.5 + drift(0.27, 4, 0.12)],
                    [0, 1], [0.5 + drift(0.31, 5, 0.12), 1], [1, 1]
                ],
                colors: Self.colors,
                smoothsColors: true
            )
        }
    }
}

#Preview {
    ScrollView {
        YouHeaderView()
    }
    .environment(ProfileStore(cloudStore: FakeCloudKeyValueStore(), database: FakeLocalDatabase()))
}
