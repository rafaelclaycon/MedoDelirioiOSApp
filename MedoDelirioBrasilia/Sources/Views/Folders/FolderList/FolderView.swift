//
//  FolderView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 28/06/22.
//

import SwiftUI

struct FolderView: View {

    let folder: UserFolder

    @State var height: CGFloat = 90

    var body: some View {
        VStack(spacing: .spacing(.xSmall)) {
            FolderIcon(
                color: folder.backgroundColor.toPastelColor(),
                emoji: folder.symbol,
                isEmpty: folder.isEmpty,
                scale: 0.85
            )

            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(folder.name)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                
                Spacer()
            }
            .padding(.leading, .spacing(.medium))
        }
    }
}

// MARK: - Subviews

extension FolderView {

    struct FolderIcon: View {

        let color: Color
        let emoji: String
        let isEmpty: Bool
        /// Scales every fixed dimension below. Kept at 1 for `FolderInfoEditingView`'s
        /// preview, which sizes this view by its own explicit `.frame(width:)`; the
        /// grid card is the only caller that wants a smaller icon.
        var scale: CGFloat = 1

        /// Grain tinted from the folder's own color rather than plain black, so it
        /// reads as texture on that folder's paper instead of a generic shadow.
        private var grainColor: Color {
            color.darkened(by: 0.22).opacity(0.5)
        }

        /// Tab top-left, flat top edge, then the "hill" — the tab's right side
        /// curving down into the body's flat top edge, macOS Finder style —
        /// then normal rounded corners the rest of the way around.
        private var backShape: FolderBackShape {
            FolderBackShape(
                tabWidth: 64 * scale,
                tabHeight: 20 * scale,
                hillRun: 30 * scale,
                tabCornerRadius: 16 * scale,
                bodyCornerRadius: 20 * scale
            )
        }

        var body: some View {
            ZStack(alignment: .top) {
                backShape
                    .fill(color)
                    .overlay { SpeckleOverlay(color: grainColor) }
                    .clipShape(backShape)
                    .frame(height: 150 * scale)

                if !isEmpty {
                    VStack {
                        Spacer()
                            .frame(height: 24 * scale)

                        RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                            .fill(Color.white)
                            .frame(height: 55 * scale)
                            .padding(.horizontal, 14 * scale)
                            .shadow(color: .black.opacity(0.12), radius: 1)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                let flapShape = RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)

                flapShape
                    .fill(color)
                    .frame(height: 110 * scale)
                    .overlay { SpeckleOverlay(color: grainColor) }
                    .clipShape(flapShape)
                    .padding(.horizontal, .spacing(.nano))
                    .modifier(PerspectiveModifier())
                    .shadow(radius: 3, y: -1)
                    .overlay {
                        Text(emoji)
                            .font(.system(size: 48 * scale))
                    }
                    .offset(y: 3 * scale)
            }
            .compositingGroup()
            .padding(.horizontal, .spacing(.nano))
        }
    }

    /// Grain is drawn as a plain `Canvas` overlay the same size as its shape's frame,
    /// which — unlike the shape itself — has square corners and no clipping of its
    /// own. Without an explicit `.clipShape` matching the shape it sits on, specks land
    /// in the corner margins the shape doesn't cover and appear to float outside it.
    struct SpeckleOverlay: View {

        var color: Color = .black.opacity(0.1)

        var body: some View {
            Canvas { context, size in
                for _ in 0..<200 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let diameter = CGFloat.random(in: 0.5...1.9)
                    let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }
}

/// The macOS Finder folder silhouette: a tab on the top-left whose right edge
/// drops into the body's top edge as a smooth "hill" — a slope, not a notch —
/// rather than the tab and body being two independently rounded rectangles.
///
/// Every corner uses `addQuadCurve` with the *sharp* corner point as the control
/// point, not `addArc`. That reads as a plain rounded corner and sidesteps
/// `addArc`'s clockwise/angle bookkeeping entirely — there are six corners and
/// curves here, and a wrong sign on any one of them self-intersects the path.
struct FolderBackShape: Shape {

    var tabWidth: CGFloat
    var tabHeight: CGFloat
    var hillRun: CGFloat
    var tabCornerRadius: CGFloat
    var bodyCornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        var path = Path()
        path.move(to: CGPoint(x: tabCornerRadius, y: 0))
        path.addLine(to: CGPoint(x: tabWidth, y: 0))

        // The hill. Tangent-flat at both ends (each control point shares its
        // endpoint's y) so it reads as one continuous slope rather than a kink.
        path.addCurve(
            to: CGPoint(x: tabWidth + hillRun, y: tabHeight),
            control1: CGPoint(x: tabWidth + hillRun * 0.5, y: 0),
            control2: CGPoint(x: tabWidth + hillRun * 0.5, y: tabHeight)
        )

        path.addLine(to: CGPoint(x: w - bodyCornerRadius, y: tabHeight))
        path.addQuadCurve(
            to: CGPoint(x: w, y: tabHeight + bodyCornerRadius),
            control: CGPoint(x: w, y: tabHeight)
        )
        path.addLine(to: CGPoint(x: w, y: h - bodyCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: w - bodyCornerRadius, y: h),
            control: CGPoint(x: w, y: h)
        )
        path.addLine(to: CGPoint(x: bodyCornerRadius, y: h))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - bodyCornerRadius),
            control: CGPoint(x: 0, y: h)
        )
        path.addLine(to: CGPoint(x: 0, y: tabCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: tabCornerRadius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

struct PerspectiveModifier: ViewModifier {

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(10),
                axis: (x: -1.0, y: 0.0, z: 0.0),
                anchor: .center,
                anchorZ: 0,
                perspective: 1
            )
    }
}

// MARK: - Preview

#Preview {
    let columns = [
        GridItem(.flexible(), spacing: 22),
        GridItem(.flexible(), spacing: 22)
    ]

    let folders = [
        UserFolder(
            symbol: "🤡",
            name: "Uso diario",
            backgroundColor: "pastelPurple",
            contentCount: 3
        ),
        UserFolder(
            symbol: "😅",
            name: "Meh",
            backgroundColor: "pastelPurple",
            contentCount: 3
        ),
        UserFolder(
            symbol: "🏙️",
            name: "Política",
            backgroundColor: "pastelPurple",
            contentCount: 0
        ),
        UserFolder(
            symbol: "🙅🏿‍♂️",
            name: "Anti-Racista",
            backgroundColor: "pastelRoyalBlue",
            contentCount: 3
        ),
        UserFolder(
            symbol: "✋",
            name: "Espera!",
            backgroundColor: "pastelPurple",
            contentCount: 3
        ),
        UserFolder(
            symbol: "🔥",
            name: "Queima!",
            backgroundColor: "pastelPurple",
            contentCount: 3
        )
    ]

    return LazyVGrid(columns: columns) {
        ForEach(folders) { folder in
            FolderView(folder: folder)
                .padding(.vertical, 6)
        }
    }
    .padding(.horizontal, .spacing(.medium))
}
