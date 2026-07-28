//
//  TranscriptCueSelectionList.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import SwiftUI

/// Scrollable list of an episode's transcript lines where the user picks the
/// clip's range by tapping a starting line and an ending line. The selected
/// range is tinted blue, with checkmarks on the endpoints and a straight line
/// connecting them through the in-between rows.
struct TranscriptCueSelectionList: View {

    let cues: [SRTCue]
    let startIndex: Int?
    let endIndex: Int?
    let onTap: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(cues.enumerated()), id: \.element.id) { index, cue in
                        TranscriptSelectionRow(text: cue.text, role: role(for: index))
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(index) }
                            .id(cue.id)
                    }
                }
                .padding(.horizontal, .spacing(.xLarge))
                .padding(.vertical, .spacing(.medium))
                .animation(.easeInOut(duration: 0.2), value: startIndex)
                .animation(.easeInOut(duration: 0.2), value: endIndex)
            }
            .onAppear {
                guard let startIndex, cues.indices.contains(startIndex) else { return }
                proxy.scrollTo(cues[startIndex].id, anchor: .center)
            }
        }
    }

    private func role(for index: Int) -> TranscriptSelectionRow.Role {
        guard let startIndex, let endIndex else { return .unselected }
        if index == startIndex, index == endIndex { return .single }
        if index == startIndex { return .start }
        if index == endIndex { return .end }
        if index > startIndex, index < endIndex { return .middle }
        return .unselected
    }
}

// MARK: - Row

struct TranscriptSelectionRow: View {

    let text: String
    let role: Role

    enum Role {
        case unselected
        /// The only selected line — start and end at once.
        case single
        case start
        /// Between start and end: no circle, just the connecting line.
        case middle
        case end

        var isSelected: Bool { self != .unselected }
    }

    private static let gutterWidth: CGFloat = 28
    private static let lineWidth: CGFloat = 2
    private static let cornerRadius: CGFloat = 12

    var body: some View {
        HStack(spacing: .spacing(.medium)) {
            gutter
                .frame(width: Self.gutterWidth)

            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .spacing(.xSmall))
        }
        .padding(.horizontal, .spacing(.small))
        .background { selectionBackground }
    }

    // MARK: - Subviews

    /// The start keeps the content-cell-style blue check; the end gets a
    /// finish-line flag. Hit testing is disabled on the checkbox so taps
    /// anywhere in the row — circle included — reach the row's own tap handler.
    private var gutter: some View {
        ZStack {
            connectorLine

            switch role {
            case .unselected:
                // Deliberately quieter than `RoundCheckbox`'s unselected state
                // so a long list of empty circles doesn't compete with the range.
                Circle()
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1.7)
                    .frame(width: Self.gutterWidth, height: Self.gutterWidth)
            case .single, .start:
                RoundCheckbox(selected: .constant(true))
                    .allowsHitTesting(false)
            case .end:
                endFlag
            case .middle:
                EmptyView()
            }
        }
    }

    private var endFlag: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: Self.gutterWidth, height: Self.gutterWidth)

            Image(systemName: "flag.checkered")
                .foregroundStyle(.white)
                .font(.system(size: 13, weight: .bold))
        }
    }

    /// Straight line connecting the start and end checkmarks. Each row draws
    /// its own segment (endpoints draw half, in-between rows draw full height);
    /// with zero list spacing the segments read as one continuous line.
    @ViewBuilder
    private var connectorLine: some View {
        switch role {
        case .start: lineSegment(top: false, bottom: true)
        case .middle: lineSegment(top: true, bottom: true)
        case .end: lineSegment(top: true, bottom: false)
        case .unselected, .single: EmptyView()
        }
    }

    private func lineSegment(top: Bool, bottom: Bool) -> some View {
        VStack(spacing: 0) {
            (top ? Color.blue : Color.clear)
                .frame(width: Self.lineWidth)
                .frame(maxHeight: .infinity)

            (bottom ? Color.blue : Color.clear)
                .frame(width: Self.lineWidth)
                .frame(maxHeight: .infinity)
        }
    }

    /// Faint blue wash over the whole selected range, with rounded corners
    /// only where the range starts and ends so the rows read as one block.
    @ViewBuilder
    private var selectionBackground: some View {
        if role.isSelected {
            let topRadius: CGFloat = (role == .start || role == .single) ? Self.cornerRadius : 0
            let bottomRadius: CGFloat = (role == .end || role == .single) ? Self.cornerRadius : 0
            UnevenRoundedRectangle(
                topLeadingRadius: topRadius,
                bottomLeadingRadius: bottomRadius,
                bottomTrailingRadius: bottomRadius,
                topTrailingRadius: topRadius,
                style: .continuous
            )
            .fill(Color.blue.opacity(0.12))
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var start: Int? = 1
        @State private var end: Int? = 3

        private let cues: [SRTCue] = [
            SRTCue(index: 1, startTime: 0, endTime: 4, text: "Boa noite, boa noite."),
            SRTCue(index: 2, startTime: 4, endTime: 8, text: "Hoje o assunto é sério, gente."),
            SRTCue(index: 3, startTime: 8, endTime: 12, text: "Vamos lá que o bagulho tá doido."),
            SRTCue(index: 4, startTime: 12, endTime: 18, text: "E aí o cara chegou lá na sessão do Congresso e falou que não ia aceitar."),
            SRTCue(index: 5, startTime: 18, endTime: 22, text: "O plenário inteiro ficou naquele burburinho."),
            SRTCue(index: 6, startTime: 22, endTime: 26, text: "Ninguém se entendendo mais."),
        ]

        var body: some View {
            TranscriptCueSelectionList(
                cues: cues,
                startIndex: start,
                endIndex: end,
                onTap: { index in
                    start = index
                    end = max(index, end ?? index)
                }
            )
        }
    }

    return PreviewWrapper()
}
