import SwiftUI

struct StandaloneSupportView: View {

    var context: Context = .generic

    @State private var toast: Toast?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacing(.large)) {
                    header

                    HelpTheAppView.DonateButtons(toast: $toast, showSectionDivider: true)
                        .padding(.horizontal, .spacing(.large))
                }
                .padding(.bottom, .spacing(.xLarge))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    CloseButton {
                        dismiss()
                    }
                }
            }
        }
        .toast($toast)
    }

    // MARK: - Header

    /// Callback to whatever the user just did, so the ask doesn't feel like
    /// it came out of nowhere, followed by the branded, breathing logo moment.
    private var header: some View {
        VStack(spacing: .spacing(.medium)) {
            Text(context.headline)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacing(.large))

            BreathingLogoView()
        }
        .padding(.top, .spacing(.small))
    }
}

// MARK: - Context

extension StandaloneSupportView {

    /// What the user just did, so the header can reflect it back to them
    /// instead of asking for support cold.
    enum Context: String, Identifiable {
        case generic
        case episodeCompleted
        case shareClip

        var id: String { rawValue }

        var headline: String {
            switch self {
            case .generic: "Curtindo o app? Que tal apoiar?"
            case .episodeCompleted: "Curtindo o podcast? Que tal apoiar o app."
            case .shareClip: "Curtiu o seu clipe? Que tal apoiar o app."
            }
        }
    }
}

// MARK: - Breathing Logo

/// The app icon slowly breathing behind a green glow — the same organic,
/// layered-sine-wave pulse used for the marketing icon in `OnboardingView`,
/// recolored for a premium, branded "here's the value, pay it back" moment.
private struct BreathingLogoView: View {

    private let logoSize: CGFloat = 76
    private let glowDiameter: CGFloat = 112

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            // Several sine waves at irrational ratios so the breathing never
            // visibly repeats, matching the onboarding icon's motion.
            let a = sin(t * 1.7) * 0.04
            let b = sin(t * 2.3) * 0.03
            let c = sin(t * 0.9) * 0.02
            let pulse = max(0, a + b + c)
            let scale = 1.0 + pulse
            let glowRadius = 8.0 + pulse * 35.0

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.green.opacity(0.55), .mint.opacity(0.15), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: glowDiameter / 2 * (1 + pulse * 2)
                        )
                    )
                    .frame(width: glowDiameter, height: glowDiameter)
                    .blur(radius: 6)

                Image("marketing-icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .green.opacity(0.5 + pulse * 3), radius: glowRadius)
                    .scaleEffect(scale)
            }
        }
        .frame(width: glowDiameter, height: glowDiameter)
    }
}

// MARK: - Preview

#Preview("Generic") {
    StandaloneSupportView()
}

#Preview("Episode Completed") {
    StandaloneSupportView(context: .episodeCompleted)
}

#Preview("Share Clip") {
    StandaloneSupportView(context: .shareClip)
}
