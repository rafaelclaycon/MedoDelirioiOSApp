//
//  TranscriptCueSelectionList.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/07/26.
//

import SwiftUI
import TipKit

/// Scrollable list of an episode's transcript lines where the user picks the
/// clip's range by tapping a starting line and an ending line. The selected
/// range is tinted blue, with checkmarks on the endpoints and a straight line
/// connecting them through the in-between rows.
struct TranscriptCueSelectionList: View {

    let cues: [SRTCue]
    let startIndex: Int?
    let endIndex: Int?
    /// The list split by chapter. The pinned titles mark where chapters change
    /// so users can find the stretch they want, and tapping one selects that
    /// whole chapter. Empty means an unsectioned list.
    var chapterSections: [TranscriptChapterSection] = []
    let onTap: (Int) -> Void
    /// Tapping a chapter header selects that chapter's full cue range.
    var onTapChapterHeader: (TranscriptChapterSection) -> Void = { _ in }

    /// Falls back to a single titleless section so the list renders the same way
    /// whether or not the episode has chapters.
    private var sections: [TranscriptChapterSection] {
        guard chapterSections.isEmpty else { return chapterSections }
        return [.init(id: 0, title: nil, cueIndices: cues.indices)]
    }

    /// The one header that teaches tap-to-select — the first titled section,
    /// since a tip on every header would just be noise.
    private var firstTitledSectionID: Int? {
        sections.first { $0.title != nil }?.id
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.cueIndices, id: \.self) { index in
                                TranscriptSelectionRow(text: cues[index].text, role: role(for: index))
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(index) }
                                    .id(cues[index].id)
                            }
                        } header: {
                            if section.title != nil {
                                ChapterSeparator(
                                    section: section,
                                    onTap: onTapChapterHeader,
                                    showsTip: section.id == firstTitledSectionID
                                )
                            }
                        }
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

// MARK: - Section

/// One chapter's worth of transcript lines. Built once by the host rather than
/// derived in `body`, which re-runs on every selection change.
struct TranscriptChapterSection: Identifiable {

    /// Index of the section's first cue, which is unique across sections.
    let id: Int
    /// Nil for the lines that play before the first chapter starts.
    let title: String?
    let cueIndices: Range<Int>
}

// MARK: - Chapter Separator

/// Chapter title pinned to the top of the list while its lines are on screen.
/// Doubles as a button: tapping it selects the whole chapter at once, so a
/// long chapter doesn't have to be picked line by line.
private struct ChapterSeparator: View {

    let section: TranscriptChapterSection
    let onTap: (TranscriptChapterSection) -> Void
    var showsTip: Bool = false

    private let tip = ChapterHeaderTapTip()

    var body: some View {
        Button {
            onTap(section)
        } label: {
            HStack {
                Text(section.title ?? "")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            // Aligned with the cue text rather than the gutter, so the title
            // reads as a label for the lines under it.
            .padding(.leading, TranscriptSelectionRow.gutterWidth + .spacing(.medium))
            .padding(.vertical, .spacing(.xSmall))
            .padding(.horizontal, .spacing(.small))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            // Pinned headers sit over scrolling content, so this has to be
            // opaque — and has to bleed past the list's own horizontal
            // padding, or lines would show through in the side margins.
            Color(.systemBackground)
                .padding(.horizontal, -.spacing(.xLarge))
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityHint("Toque para selecionar este capítulo inteiro")
        .popoverTip(showsTip ? tip : nil)
        .tipViewStyle(PrimaryImageTipViewStyle(tip: tip))
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

    /// Shared with `ChapterSeparator` so its title lines up with the cue text.
    fileprivate static let gutterWidth: CGFloat = 28
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
                chapterSections: [
                    .init(id: 0, title: "Abertura", cueIndices: 0..<3),
                    .init(id: 3, title: "A sessão do Congresso", cueIndices: 3..<6),
                ],
                onTap: { index in
                    start = index
                    end = max(index, end ?? index)
                },
                onTapChapterHeader: { section in
                    start = section.cueIndices.lowerBound
                    end = section.cueIndices.upperBound - 1
                }
            )
        }
    }

    return PreviewWrapper()
}
