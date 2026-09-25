//
//  ElectionLiveActivity.swift
//  MedoDelirioWidget
//
//  Created by Rafael Schmitt on 24/09/26.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ElectionLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ElectionActivityAttributes.self) { context in
            ElectionLockScreenView(round: context.attributes.round, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Presidente", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ElectionFormat.sections(state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ForEach(Array(state.candidates.prefix(3).enumerated()), id: \.element.id) { index, candidate in
                            ElectionCandidateRow(candidate: candidate, rank: index)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                if let leader = state.leader {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ElectionFormat.color(for: leader, rank: 0))
                            .frame(width: 8, height: 8)
                        Text(leader.name)
                            .lineLimit(1)
                            .frame(maxWidth: 64)
                    }
                    .font(.caption2)
                }
            } compactTrailing: {
                if let leader = state.leader {
                    Text(ElectionFormat.percent(leader.percent))
                        .font(.caption2)
                        .monospacedDigit()
                }
            } minimal: {
                Gauge(value: state.sectionsCountedPercent, in: 0...100) {
                    Image(systemName: "checkmark.seal.fill")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.green)
            }
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen

struct ElectionLockScreenView: View {

    let round: Int
    let state: ElectionActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Presidente · \(round)º turno")
                    .font(.subheadline)
                    .fontWeight(.bold)
                Spacer()
                Text(ElectionFormat.sections(state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: state.sectionsCountedPercent, total: 100)
                .tint(.green)

            VStack(spacing: 6) {
                ForEach(Array(state.candidates.prefix(4).enumerated()), id: \.element.id) { index, candidate in
                    ElectionCandidateRow(candidate: candidate, rank: index)
                }
            }

            Text(footer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding()
    }

    private var footer: String {
        if isStale {
            return "Fonte: TSE · atualização atrasada"
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
        return "Fonte: TSE · \(state.updatedAtDate.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - Candidate Row

struct ElectionCandidateRow: View {

    let candidate: ElectionActivityAttributes.Candidate
    let rank: Int

    var body: some View {
        let color = ElectionFormat.color(for: candidate, rank: rank)
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Text(candidate.name)
                    .fontWeight(rank == 0 ? .semibold : .regular)
                    .lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 4)
                        .background(color.opacity(0.3), in: .capsule)
                }
                Spacer(minLength: 4)
                Text(ElectionFormat.percent(candidate.percent))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.caption)

            GeometryReader { proxy in
                Capsule()
                    .fill(color)
                    .frame(width: max(4, proxy.size.width * min(candidate.percent, 100) / 100))
            }
            .frame(height: 4)
        }
    }

    private var badge: String? {
        switch candidate.status {
        case .elected: "ELEITO"
        case .runoff: "2º TURNO"
        case .counting, .notElected: nil
        }
    }
}

// MARK: - Formatting

enum ElectionFormat {

    private static let fallbackColors: [Color] = [.red, .blue, .yellow, .purple]

    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "pt_BR"))) + "%"
    }

    static func sections(_ state: ElectionActivityAttributes.ContentState) -> String {
        "\(percent(state.sectionsCountedPercent)) apurado"
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
        sectionsCountedPercent: 62.4,
        isFinal: false,
        updatedAt: 1_790_277_154,
        candidates: [
            .init(number: 89, name: "Candidato string 1234!@#$\"TSE\"", party: "P 9972", percent: 38.7, status: .counting, colorHex: "#D62828"),
            .init(number: 57, name: "CANDIDATO 9999", party: "P 9998", percent: 34.2, status: .counting, colorHex: "#1D4E89"),
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
