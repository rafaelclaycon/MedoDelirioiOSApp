//
//  WaveformView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Claycon Schmitt on 24/02/26.
//

import SwiftUI

/// Renders a horizontally scrollable audio waveform with a resizable,
/// draggable clip selection region and an optional play head.
struct WaveformView: View {

    let samples: [Float]
    let duration: TimeInterval

    @Binding var clipStart: TimeInterval
    @Binding var clipEnd: TimeInterval

    var playheadTime: TimeInterval = 0
    var showPlayhead: Bool = false
    var onPlayheadDrag: ((TimeInterval) -> Void)? = nil

    private static let barWidth: CGFloat = 3
    private static let barSpacing: CGFloat = 2
    private static let barCornerRadius: CGFloat = 2
    private static let viewHeight: CGFloat = 100
    private static let minClipLength: TimeInterval = 1

    private static let edgeHandleWidth: CGFloat = 10
    private static let edgeHandleCornerRadius: CGFloat = 4
    private static let edgeHitArea: CGFloat = 36

    private static let playheadProtrusion: CGFloat = 24
    private static let totalHeight: CGFloat = viewHeight + playheadProtrusion

    private var step: CGFloat { Self.barWidth + Self.barSpacing }

    private var totalContentWidth: CGFloat {
        CGFloat(samples.count) * step
    }

    private var clipXOffset: CGFloat {
        CGFloat(clipStart / max(duration, 1)) * totalContentWidth
    }

    private var clipEndXOffset: CGFloat {
        CGFloat(clipEnd / max(duration, 1)) * totalContentWidth
    }

    private var clipRegionWidth: CGFloat {
        clipEndXOffset - clipXOffset
    }

    private var playheadXOffset: CGFloat {
        CGFloat(playheadTime / max(duration, 1)) * totalContentWidth
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<samples.count, id: \.self) { index in
                        Color.clear
                            .frame(width: step, height: Self.totalHeight)
                            .id(index)
                    }
                }
                .overlay(alignment: .bottom) {
                    waveformCanvas
                        .frame(height: Self.viewHeight)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    clipBodyOverlay
                }
                .overlay(alignment: .bottomLeading) {
                    leftEdgeHandle
                }
                .overlay(alignment: .bottomLeading) {
                    rightEdgeHandle
                }
                .overlay(alignment: .leading) {
                    if showPlayhead {
                        playheadOverlay
                    }
                }
                .coordinateSpace(.named("waveform"))
            }
            .frame(height: Self.totalHeight)
            .onAppear {
                guard !samples.isEmpty else { return }
                proxy.scrollTo(targetBarIndex, anchor: .center)
            }
        }
    }

    // MARK: - Waveform

    private var waveformCanvas: some View {
        Canvas { context, size in
            let cX = clipXOffset
            let cEndX = clipEndXOffset
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) * step
                let amplitude = CGFloat(max(sample, 0.05))
                let barHeight = amplitude * size.height
                let y = (size.height - barHeight) / 2

                let barMidX = x + Self.barWidth / 2
                let insideClip = barMidX >= cX && barMidX <= cEndX

                let rect = CGRect(x: x, y: y, width: Self.barWidth, height: barHeight)
                let path = Path(roundedRect: rect, cornerRadius: Self.barCornerRadius)
                context.fill(path, with: .color(insideClip ? .green : .secondary.opacity(0.35)))
            }
        }
    }

    // MARK: - Clip Region

    private var clipBodyOverlay: some View {
        RoundedRectangle(cornerRadius: Self.edgeHandleCornerRadius)
            .strokeBorder(Color.darkestGreen, lineWidth: 2)
            .frame(width: clipRegionWidth, height: Self.viewHeight)
            .offset(x: clipXOffset)
            .gesture(
                DragGesture(coordinateSpace: .named("waveform"))
                    .onChanged { value in
                        let length = clipEnd - clipStart
                        let center = TimeInterval(value.location.x / totalContentWidth) * duration
                        var newStart = center - length / 2
                        newStart = min(max(newStart, 0), duration - length)
                        clipStart = newStart
                        clipEnd = newStart + length
                    }
            )
    }

    private var leftEdgeHandle: some View {
        edgeHandleView(
            corners: .init(
                topLeading: Self.edgeHandleCornerRadius,
                bottomLeading: Self.edgeHandleCornerRadius
            )
        )
        .offset(x: clipXOffset - Self.edgeHandleWidth - (Self.edgeHitArea - Self.edgeHandleWidth) / 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("waveform"))
                .onChanged { value in
                    let newStart = TimeInterval(value.location.x / totalContentWidth) * duration
                    let maxStart = clipEnd - Self.minClipLength
                    clipStart = min(max(newStart, 0), maxStart)
                }
        )
    }

    private var rightEdgeHandle: some View {
        edgeHandleView(
            corners: .init(
                bottomTrailing: Self.edgeHandleCornerRadius,
                topTrailing: Self.edgeHandleCornerRadius
            )
        )
        .offset(x: clipEndXOffset - (Self.edgeHitArea - Self.edgeHandleWidth) / 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("waveform"))
                .onChanged { value in
                    let newEnd = TimeInterval(value.location.x / totalContentWidth) * duration
                    let minEnd = clipStart + Self.minClipLength
                    clipEnd = max(min(newEnd, duration), minEnd)
                }
        )
    }

    private func edgeHandleView(corners: RectangleCornerRadii) -> some View {
        ZStack {
            UnevenRoundedRectangle(cornerRadii: corners)
                .fill(Color.darkestGreen)

            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 16)
                }
            }
        }
        .frame(width: Self.edgeHandleWidth, height: Self.viewHeight)
        .padding(.horizontal, (Self.edgeHitArea - Self.edgeHandleWidth) / 2)
        .contentShape(Rectangle())
    }

    // MARK: - Playhead

    private var playheadOverlay: some View {
        VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Color.red)

                HStack(spacing: 1.5) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 1, height: 10)
                    }
                }
            }
            .frame(width: 12, height: 22)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)

            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
        }
        .frame(width: Self.edgeHitArea, height: Self.totalHeight)
        .contentShape(Rectangle())
        .offset(x: playheadXOffset - Self.edgeHitArea / 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("waveform"))
                .onChanged { value in
                    let newTime = TimeInterval(value.location.x / totalContentWidth) * duration
                    let clamped = min(max(newTime, clipStart), clipEnd)
                    onPlayheadDrag?(clamped)
                }
        )
    }

    // MARK: - Helpers

    private var targetBarIndex: Int {
        let centerTime = (clipStart + clipEnd) / 2
        let fraction = centerTime / max(duration, 1)
        let bar = Int(fraction * Double(samples.count))
        return min(max(bar, 0), max(samples.count - 1, 0))
    }
}
