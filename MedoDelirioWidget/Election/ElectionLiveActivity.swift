//
//  ElectionLiveActivity.swift
//  MedoDelirioWidget
//
//  Created by Rafael Schmitt on 24/09/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Only the top two matter: the leader on the left, second place on the right, like the
/// indie election apps of 2022. Always dark green, after the app's colors.
struct ElectionLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ElectionActivityAttributes.self) { context in
            ElectionLockScreenView(round: context.attributes.round, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(ElectionPalette.body)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(ElectionPalette.resultsURL)
        } dynamicIsland: { context in
            let state = context.state
            let (first, second) = ElectionFormat.topTwo(state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ElectionCandidateSide(candidate: first, rank: 0, alignment: .leading, badgeSize: 30)
                        .padding(.leading, 4)
                        .dynamicTypeSize(.large)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElectionCandidateSide(candidate: second, rank: 1, alignment: .trailing, badgeSize: 30)
                        .padding(.trailing, 4)
                        .dynamicTypeSize(.large)
                }
                // No center region: it takes width from the percentages.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ElectionNamesRow(first: first, second: second)
                        ElectionCountedRow(round: context.attributes.round, state: state, font: .caption)
                        // Inset and lifted: the island's rounded bottom corners cut off
                        // the ends of a full-width bar.
                        ElectionProgressBar(percent: state.sectionsCountedPercent)
                            .padding(.horizontal, 18)
                            .padding(.bottom, 6)
                    }
                    .padding(.horizontal, 4)
                    .dynamicTypeSize(.large)
                }
            } compactLeading: {
                if let first {
                    HStack(spacing: 4) {
                        ElectionCandidateBadge(candidate: first, rank: 0, size: 20)
                        Text(ElectionFormat.percent(first.percent, digits: 1))
                            .monospacedDigit()
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                }
            } compactTrailing: {
                if let second {
                    HStack(spacing: 4) {
                        Text(ElectionFormat.percent(second.percent, digits: 1))
                            .monospacedDigit()
                        ElectionCandidateBadge(candidate: second, rank: 1, size: 20)
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                }
            } minimal: {
                Image("ElectionPodcastLogo")
                    .resizable()
                    .scaledToFit()
            }
            .keylineTint(ElectionPalette.bar)
            .widgetURL(ElectionPalette.resultsURL)
        }
    }
}

// MARK: - Lock Screen

struct ElectionLockScreenView: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        let (first, second) = ElectionFormat.topTwo(state)
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    ElectionCandidateSide(candidate: first, rank: 0, alignment: .leading, badgeSize: 36)
                    Spacer(minLength: 4)
                    ElectionRoundLabel(round: round, isLive: !state.isFinal)
                    Spacer(minLength: 4)
                    ElectionCandidateSide(candidate: second, rank: 1, alignment: .trailing, badgeSize: 36)
                }
                ElectionNamesRow(first: first, second: second)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ElectionPalette.header)

            // Tight on purpose: the Lock Screen cuts a Live Activity taller than 160 pt.
            VStack(spacing: 6) {
                Text(ElectionFormat.counted(state))
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()

                ElectionProgressBar(percent: state.sectionsCountedPercent)

                // The final message takes the footer's place: a line more would pass the
                // Live Activity's maximum height and get cut.
                HStack(spacing: 6) {
                    Image("ElectionAppLogo")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(.rect(cornerRadius: 4))
                    if state.isFinal, let finalMessage = state.finalMessage {
                        Text(finalMessage)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(footer)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            // Not left to `activityBackgroundTint` alone: in light mode the system can still
            // lay the activity over a white background.
            .background(ElectionPalette.body)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // Fixed at the default text size: with the round between the percentages, larger
        // sizes push the photos out on narrow iPhones, and the Lock Screen cuts anything
        // taller than 160 pt.
        .dynamicTypeSize(.large)
    }

    private var footer: String {
        let time = state.updatedAtDate.formatted(date: .omitted, time: .shortened)
        if isStale {
            return "Atualização atrasada · última às \(time)"
        }
        if state.isFinal {
            let runoff = state.candidates.filter { $0.status == .runoff }
            if runoff.count == 2 {
                return "2º turno entre \(runoff[0].name) e \(runoff[1].name)"
            }
            if let elected = state.candidates.first(where: { $0.status == .elected }) {
                return "\(elected.name) eleito(a) · Fonte: TSE"
            }
            return "Apuração encerrada · Fonte: TSE"
        }
        return "Atualizado às \(time) · Fonte: TSE"
    }
}

// MARK: - Pieces

/// Badge and share of valid votes, mirrored on the trailing side. The names go in
/// `ElectionNamesRow`. Font sizes are fixed on purpose.
struct ElectionCandidateSide: View {

    let candidate: ElectionActivityAttributes.Candidate?
    let rank: Int
    let alignment: HorizontalAlignment
    let badgeSize: CGFloat

    var body: some View {
        if let candidate {
            HStack(spacing: 8) {
                if alignment == .leading {
                    ElectionCandidateBadge(candidate: candidate, rank: rank, size: badgeSize)
                }
                Text(ElectionFormat.percent(candidate.percent, digits: 2))
                    .font(badgeSize > 32 ? .title3 : .headline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                if alignment == .trailing {
                    ElectionCandidateBadge(candidate: candidate, rank: rank, size: badgeSize)
                }
            }
        }
    }
}

/// "● 1º TURNO   19,00% TOTALIZADO": the round and the live dot share the line with the
/// counted share, leaving the top row to the candidates.
struct ElectionCountedRow: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let font: Font

    var body: some View {
        HStack(spacing: 10) {
            ElectionRoundLabel(round: round, isLive: !state.isFinal)
            Text(ElectionFormat.counted(state))
                .font(font)
                .fontWeight(.bold)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

/// Names get a row of their own, half the width each: at a fixed size, a name like
/// FLAVIO BOLSONARO doesn't fit next to the photo.
struct ElectionNamesRow: View {

    let first: ElectionActivityAttributes.Candidate?
    let second: ElectionActivityAttributes.Candidate?

    var body: some View {
        HStack(spacing: 8) {
            Text(first?.name ?? "")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(second?.name ?? "")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

/// The candidate's official TSE photo when the widget has one (`ElectionCandidate<number>`
/// in the asset catalog), otherwise their color with the ballot number.
struct ElectionCandidateBadge: View {

    let candidate: ElectionActivityAttributes.Candidate
    let rank: Int
    let size: CGFloat

    var body: some View {
        content
            .frame(width: size, height: size)
            .clipShape(.circle)
            .overlay {
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let photo = UIImage(named: "ElectionCandidate\(candidate.number)") {
            // TSE photos are portraits: anchored to the top so the face stays in the circle.
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size, alignment: .top)
        } else {
            Circle()
                .fill(ElectionFormat.color(for: candidate, rank: rank))
                .overlay {
                    Text(String(candidate.number))
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.white)
                        .padding(size * 0.12)
                }
        }
    }
}

/// The red dot means the count is live; it goes away with the final result.
struct ElectionRoundLabel: View {

    let round: Int
    let isLive: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isLive {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
            }
            Text("\(round)º TURNO")
                .font(.caption2)
                .fontWeight(.heavy)
                .fixedSize()
        }
    }
}

struct ElectionProgressBar: View {

    let percent: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(ElectionPalette.bar)
                    .frame(width: max(8, proxy.size.width * min(max(percent, 0), 100) / 100))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Style

enum ElectionPalette {

    /// Band behind the two candidates.
    static let header = Color(red: 0.03, green: 0.20, blue: 0.11)
    /// Everything else.
    static let body = Color(red: 0.06, green: 0.29, blue: 0.16)
    static let bar = Color(red: 1, green: 0.84, blue: 0)

    /// Tapping the activity opens the app's results screen.
    static let resultsURL = URL(string: "medodelirio://apuracao")!
}

enum ElectionFormat {

    private static let fallbackColors: [Color] = [.red, .blue]
    private static let locale = Locale(identifier: "pt_BR")

    /// The server already sends candidates ordered by votes.
    static func topTwo(_ state: ElectionActivityAttributes.ContentState) -> (ElectionActivityAttributes.Candidate?, ElectionActivityAttributes.Candidate?) {
        (state.candidates.first, state.candidates.dropFirst().first)
    }

    static func percent(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(locale)) + "%"
    }

    static func counted(_ state: ElectionActivityAttributes.ContentState) -> String {
        "\(percent(state.sectionsCountedPercent, digits: 2)) TOTALIZADO"
    }

    static func color(for candidate: ElectionActivityAttributes.Candidate, rank: Int) -> Color {
        if let hex = candidate.colorHex, let color = Color(electionHex: hex) {
            return color
        }
        return fallbackColors[rank % fallbackColors.count]
    }
}

private extension Color {

    init?(electionHex hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

// MARK: - Preview

extension ElectionActivityAttributes.ContentState {

    static let previewCounting = Self(
        sectionsCountedPercent: 65.57,
        isFinal: false,
        updatedAt: 1_790_277_154,
        candidates: [
            .init(number: 89, name: "Candidato string 1234!@#$\"TSE\"", party: "P 9972", percent: 50.03, status: .counting, colorHex: "#D62828"),
            .init(number: 57, name: "CANDIDATO 9999", party: "P 9998", percent: 49.97, status: .counting, colorHex: "#1D4E89"),
            .init(number: 68, name: "CANDIDATO 9987", party: "P 9996", percent: 9.1, status: .counting, colorHex: nil),
            .init(number: 88, name: "CANDIDATO 9977", party: "P 9973", percent: 6.3, status: .counting, colorHex: nil)
        ]
    )

    static let previewFinal = Self(
        sectionsCountedPercent: 100,
        isFinal: true,
        updatedAt: 1_790_277_154,
        candidates: [
            .init(number: 57, name: "CANDIDATO 9999", party: "P 9998", percent: 41.3, status: .runoff, colorHex: "#1D4E89"),
            .init(number: 89, name: "Candidato string 1234!@#$\"TSE\"", party: "P 9972", percent: 39.8, status: .runoff, colorHex: "#D62828"),
            .init(number: 68, name: "CANDIDATO 9987", party: "P 9996", percent: 8.2, status: .notElected, colorHex: nil),
            .init(number: 88, name: "CANDIDATO 9977", party: "P 9973", percent: 5.9, status: .notElected, colorHex: nil)
        ]
    )

    /// Ballot numbers with photos in the asset catalog.
    static let previewWithPhotos = Self(
        sectionsCountedPercent: 48.2,
        isFinal: false,
        updatedAt: 1_790_277_154,
        candidates: [
            .init(number: 13, name: "LULA", party: "PT", percent: 47.12, status: .counting, colorHex: nil),
            .init(number: 22, name: "FLAVIO BOLSONARO", party: "PL", percent: 38.45, status: .counting, colorHex: nil)
        ]
    )

    static let previewFinalWithMessage: Self = {
        var state = previewFinal
        state.finalMessage = "Segura que ainda tem 2º turno. Bora!"
        return state
    }()
}

#Preview("Lock Screen", as: .content, using: ElectionActivityAttributes(round: 1)) {
    ElectionLiveActivity()
} contentStates: {
    ElectionActivityAttributes.ContentState.previewCounting
    ElectionActivityAttributes.ContentState.previewWithPhotos
    ElectionActivityAttributes.ContentState.previewFinal
    ElectionActivityAttributes.ContentState.previewFinalWithMessage
}

#Preview("Island Expanded", as: .dynamicIsland(.expanded), using: ElectionActivityAttributes(round: 1)) {
    ElectionLiveActivity()
} contentStates: {
    ElectionActivityAttributes.ContentState.previewCounting
}

#Preview("Island Compact", as: .dynamicIsland(.compact), using: ElectionActivityAttributes(round: 1)) {
    ElectionLiveActivity()
} contentStates: {
    ElectionActivityAttributes.ContentState.previewCounting
}

#Preview("Island Minimal", as: .dynamicIsland(.minimal), using: ElectionActivityAttributes(round: 1)) {
    ElectionLiveActivity()
} contentStates: {
    ElectionActivityAttributes.ContentState.previewCounting
}
