//
//  ElectionKeypadPatternView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 27/09/26.
//

import SwiftUI

/// Mini ballot machine keypads tiled behind the header: digits 1 to 9 with 0 under the 8,
/// and BRANCO, CORRIGE and CONFIRMA in their real colors. A dot on each key hints at the
/// braille. Few, large and faint, and gone behind the photos and the title: smaller or
/// denser keypads turn into noise.
struct ElectionKeypadPatternView: View {

    private static let key = CGSize(width: 14, height: 10)
    private static let actionWidth: CGFloat = 22
    private static let gap: CGFloat = 3
    private static let padding: CGFloat = 4
    private static let angle = Angle.degrees(-12)
    private static let scale: CGFloat = 1.35
    private static let spacing = CGSize(width: 34, height: 26)

    private static var keypadSize: CGSize {
        CGSize(
            width: padding * 2 + key.width * 3 + actionWidth + gap * 3,
            height: padding * 2 + key.height * 4 + gap * 3
        )
    }

    var body: some View {
        Canvas { context, size in
            let tile = Self.keypadSize
            let step = CGSize(width: tile.width + Self.spacing.width, height: tile.height + Self.spacing.height)
            // Rotated around the center, so the grid overshoots to cover the corners.
            let reach = hypot(size.width, size.height) / 2 / Self.scale
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: Self.scale, y: Self.scale)
            context.rotate(by: Self.angle)

            var row = 0
            var y = -reach
            while y < reach {
                var x = -reach + (row.isMultiple(of: 2) ? 0 : step.width / 2)
                while x < reach {
                    drawKeypad(in: &context, at: CGPoint(x: x, y: y))
                    x += step.width
                }
                y += step.height
                row += 1
            }
        }
        .opacity(0.55)
        // Clear behind the photos and the title, visible toward the edges.
        .mask {
            RadialGradient(
                colors: [.clear, .clear, .white],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 0,
                endRadius: 230
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawKeypad(in context: inout GraphicsContext, at origin: CGPoint) {
        let key = Self.key, gap = Self.gap, padding = Self.padding
        let frame = CGRect(origin: origin, size: Self.keypadSize)
        context.stroke(
            Path(roundedRect: frame, cornerRadius: 5),
            with: .color(.white.opacity(0.08)),
            lineWidth: 0.8
        )

        func keyRect(column: Int, row: Int, width: CGFloat = key.width, rows: Int = 1) -> CGRect {
            CGRect(
                x: frame.minX + padding + CGFloat(column) * (key.width + gap),
                y: frame.minY + padding + CGFloat(row) * (key.height + gap),
                width: width,
                height: key.height * CGFloat(rows) + gap * CGFloat(rows - 1)
            )
        }

        let digits: [(String, Int, Int)] = [
            ("1", 0, 0), ("2", 1, 0), ("3", 2, 0),
            ("4", 0, 1), ("5", 1, 1), ("6", 2, 1),
            ("7", 0, 2), ("8", 1, 2), ("9", 2, 2),
            ("0", 1, 3)
        ]
        for (digit, column, row) in digits {
            let rect = keyRect(column: column, row: row)
            context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(.black.opacity(0.18)))
            context.draw(
                Text(digit)
                    .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.22)),
                at: CGPoint(x: rect.minX + 4, y: rect.midY)
            )
            context.fill(
                Path(ellipseIn: CGRect(x: rect.maxX - 4.5, y: rect.minY + 2.5, width: 1.6, height: 1.6)),
                with: .color(.white.opacity(0.18))
            )
        }

        // CONFIRMA is a lighter green, or it'd vanish into the background.
        let actions: [(Color, Double, Int, Int)] = [
            (.white, 0.2, 0, 1),
            (Color(red: 0.88, green: 0.44, blue: 0.20), 0.2, 1, 1),
            (Color(red: 0.55, green: 0.85, blue: 0.45), 0.3, 2, 2)
        ]
        for (color, opacity, row, rows) in actions {
            let rect = keyRect(column: 3, row: row, width: Self.actionWidth, rows: rows)
            context.fill(Path(roundedRect: rect, cornerRadius: 2.5), with: .color(color.opacity(opacity)))
        }
    }
}
