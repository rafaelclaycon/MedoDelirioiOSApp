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
        } dynamicIsland: { context in
            let state = context.state
            let (first, second) = ElectionFormat.topTwo(state)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ElectionCandidateSide(candidate: first, rank: 0, alignment: .leading, badgeSize: 30)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElectionCandidateSide(candidate: second, rank: 1, alignment: .trailing, badgeSize: 30)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    ElectionRoundLabel(round: context.attributes.round, isLive: !state.isFinal)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text(ElectionFormat.counted(state))
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                        ElectionProgressBar(percent: state.sectionsCountedPercent)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
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
                Gauge(value: state.sectionsCountedPercent, in: 0...100) {
                    Image("ElectionAppLogo")
                        .resizable()
                        .clipShape(.circle)
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(ElectionPalette.bar)
            }
            .keylineTint(ElectionPalette.bar)
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
            HStack(spacing: 8) {
                ElectionCandidateSide(candidate: first, rank: 0, alignment: .leading, badgeSize: 40)
                Spacer(minLength: 4)
                ElectionRoundLabel(round: round, isLive: !state.isFinal)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                ElectionCandidateSide(candidate: second, rank: 1, alignment: .trailing, badgeSize: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ElectionPalette.header)

            VStack(spacing: 8) {
                Text(ElectionFormat.counted(state))
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()

                ElectionProgressBar(percent: state.sectionsCountedPercent)

                HStack(spacing: 6) {
                    Image("ElectionAppLogo")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .clipShape(.rect(cornerRadius: 4))
                    Text(footer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            // Not left to `activityBackgroundTint` alone: in light mode the system can still
            // lay the activity over a white background.
            .background(ElectionPalette.body)
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
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

/// Badge, share of valid votes and name, mirrored on the trailing side.
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
                VStack(alignment: alignment, spacing: 0) {
                    Text(ElectionFormat.percent(candidate.percent, digits: 2))
                        .font(badgeSize > 32 ? .title2 : .headline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                    Text(candidate.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .lineLimit(1)
                if alignment == .trailing {
                    ElectionCandidateBadge(candidate: candidate, rank: rank, size: badgeSize)
                }
            }
        }
    }
}

/// Stands in for the candidate's photo: their color with the ballot number.
struct ElectionCandidateBadge: View {

    let candidate: ElectionActivityAttributes.Candidate
    let rank: Int
    let size: CGFloat

    var body: some View {
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
            .overlay {
                Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1.5)
            }
            .frame(width: size, height: size)
    }
}

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
}

#Preview("Lock Screen", as: .content, using: ElectionActivityAttributes(round: 1)) {
    ElectionLiveActivity()
} contentStates: {
    ElectionActivityAttributes.ContentState.previewCounting
    ElectionActivityAttributes.ContentState.previewFinal
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
