//
//  ProfilePhotoCropView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 15/10/26.
//

import SwiftUI

/// A photo picked from the library, to frame in the avatar's circle: drag to move,
/// pinch to zoom. "Usar" hands back a small square JPEG (`ProfilePhoto`).
struct ProfilePhotoCropView: View {

    let image: UIImage
    let onUse: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var offsetAtGestureStart: CGSize = .zero

    private static let viewport: CGFloat = 300
    private static let maxZoom: CGFloat = 5

    /// The photo filling the square at zoom 1, keeping its proportions.
    private var baseSize: CGSize {
        let aspect = image.size.width / max(image.size.height, 1)
        return aspect >= 1
            ? CGSize(width: Self.viewport * aspect, height: Self.viewport)
            : CGSize(width: Self.viewport, height: Self.viewport / aspect)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: .spacing(.large)) {
                Spacer()

                cropArea

                Text("Arraste pra posicionar e use dois dedos pra aproximar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationTitle("Ajustar foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Usar") {
                        use()
                    }
                }
            }
        }
    }

    /// Exactly what gets saved: the square the circle sits in.
    private var framed: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: baseSize.width * zoom, height: baseSize.height * zoom)
            .offset(offset)
            .frame(width: Self.viewport, height: Self.viewport)
            .clipped()
    }

    private var cropArea: some View {
        framed
            .overlay {
                // Dims what falls outside the circle, which the avatar won't show.
                Rectangle()
                    .fill(.black.opacity(0.55))
                    .mask {
                        Rectangle()
                            .overlay {
                                Circle()
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                    .allowsHitTesting(false)
            }
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(SimultaneousGesture(drag, magnify))
            .accessibilityLabel("Foto escolhida, para ajustar")
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: offsetAtGestureStart.width + value.translation.width,
                    height: offsetAtGestureStart.height + value.translation.height
                )
                offset = clamped(proposed, zoom: zoom)
            }
            .onEnded { _ in
                offsetAtGestureStart = offset
            }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(max(zoomAtGestureStart * value.magnification, 1), Self.maxZoom)
                offset = clamped(offset, zoom: zoom)
            }
            .onEnded { _ in
                zoomAtGestureStart = zoom
                offsetAtGestureStart = offset
            }
    }

    /// Keeps the photo covering the whole square, so the circle never shows a gap.
    private func clamped(_ offset: CGSize, zoom: CGFloat) -> CGSize {
        let maxX = max(0, (baseSize.width * zoom - Self.viewport) / 2)
        let maxY = max(0, (baseSize.height * zoom - Self.viewport) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func use() {
        let renderer = ImageRenderer(content: framed)
        renderer.scale = ProfilePhoto.side / Self.viewport
        if let rendered = renderer.uiImage, let data = ProfilePhoto.thumbnailData(from: rendered) {
            onUse(data)
        }
        dismiss()
    }
}
