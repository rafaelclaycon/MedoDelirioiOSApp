//
//  SectionColumns.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 11/10/26.
//

import SwiftUI

/// Lays out sections in as many columns as fit `minColumnWidth`, so a wide window shows
/// rankings side by side instead of stretching each one across it.
///
/// Sections go round-robin (first column, second column, then back), and each column
/// stacks its own: one section growing, like a ranking expanded with Ver Mais, only
/// pushes down what's under it, and never moves sections to another column.
struct SectionColumns: Layout {

    var minColumnWidth: CGFloat
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? minColumnWidth
        let frames = frames(for: subviews, width: width)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(for: subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    // MARK: - Private

    private func columnCount(for width: CGFloat, sectionCount: Int) -> Int {
        let fitting = Int((width + horizontalSpacing) / (minColumnWidth + horizontalSpacing))
        return max(1, min(fitting, sectionCount))
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        let columns = columnCount(for: width, sectionCount: subviews.count)
        let columnWidth = (width - CGFloat(columns - 1) * horizontalSpacing) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat.zero, count: columns)

        return subviews.enumerated().map { index, subview in
            let column = index % columns
            let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            let y = index < columns ? 0 : columnHeights[column] + verticalSpacing
            columnHeights[column] = y + height
            return CGRect(
                x: CGFloat(column) * (columnWidth + horizontalSpacing),
                y: y,
                width: columnWidth,
                height: height
            )
        }
    }
}
