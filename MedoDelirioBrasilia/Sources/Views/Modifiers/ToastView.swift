//
//  ToastView.swift
//  MedoDelirioBrasilia
//
//  Created by Rafael Schmitt on 24/11/24.
//

import SwiftUI

// MARK: - Models

public enum ToastType {
    
    case success, warning, wait, thankYou
}

public struct Toast {

    public let message: String
    public let type: ToastType

    public init(
        message: String,
        type: ToastType
    ) {
        self.message = message
        self.type = type
    }
}

// MARK: - Reusable Views

struct ToastView {

    private struct MainLabel: View {

        let toast: Toast

        @Environment(\.colorScheme) private var colorScheme

        private var icon: String {
            switch toast.type {
            case .success:
                "checkmark"
            case .warning:
                "exclamationmark.triangle.fill"
            case .wait:
                "clock.fill"
            case .thankYou:
                "heart"
            }
        }

        private var iconColor: Color {
            switch toast.type {
            case .success:
                .green
            case .warning:
                .orange
            case .wait:
                .orange
            case .thankYou:
                .pink
            }
        }

        var body: some View {
            Label {
                Text(toast.message)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .font(.callout)
                    .bold()
            } icon: {
                Image(systemName: icon)
                    .font(Font.system(size: 20, weight: .bold))
                    .foregroundColor(iconColor)
            }
            .labelStyle(.centerAligned)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .spacing(.huge), style: .continuous)
                    .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
                    .shadow(
                        color: colorScheme == .dark ? .white.opacity(0.5) : .black.opacity(0.3),
                        radius: colorScheme == .dark ? 4 : 2,
                        y: colorScheme == .dark ? 0 : 2
                    )
            }
            .padding([.horizontal,.vertical], .spacing(.medium))
        }
    }
}

// MARK: - Specific Views

extension ToastView {

    struct Scaffolding: ViewModifier {

        @Binding private var toast: Toast?
        let isTop: Bool

        public init(
            _ toast: Binding<Toast?>,
            isTop: Bool = false
        ) {
            self._toast = toast
            self.isTop = isTop
        }

        public func body(content: Content) -> some View {
            content
                .overlay(alignment: isTop ? .top : .bottom) {
                    if let toast {
                        MainLabel(toast: toast)
                            .onAppear {
                                switch toast.type {
                                case .success:
                                    HapticFeedback.success()
                                case .warning:
                                    HapticFeedback.warning()
                                case .wait:
                                    HapticFeedback.warning()
                                case .thankYou:
                                    HapticFeedback.success()
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                    self.toast = nil
                                }
                            }
                            .animation(.easeInOut, value: self.toast != nil)
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        if value.translation.height < 0 {
                                            self.toast = nil
                                        }
                                    }
                            )
                            .dynamicTypeSize(.xSmall ... .accessibility1)
                    }
                }
        }
    }
}

// MARK: - Modifiers

public extension View {

    /// Adds a bottom-aligned, dark-mode-aware toast overlay.
    ///
    /// Renders as an overlay rather than a safe-area inset so it doesn't
    /// reflow surrounding layout when it appears. Attach it to content that
    /// already sits above any bottom-bar toolbar (e.g. before `.toolbar` in
    /// the modifier chain) so the overlay's bottom edge lands above the bar
    /// instead of underneath it.
    /// - Parameters:
    ///   - toast: Binding to a toast to display. When nil, toast is not presented.
    func toast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastView.Scaffolding(toast))
    }

    /// Adds a top-aligned, dark-mode-aware toast overlay.
    func topToast(_ toast: Binding<Toast?>) -> some View {
        modifier(ToastView.Scaffolding(toast, isTop: true))
    }
}

// MARK: - Previews

#Preview {
    VStack(spacing: .spacing(.xLarge)) {
        VStack {
            Text("Success Toast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.pink)
        .toast(
            .constant(
                Toast(message: Shared.soundSharedSuccessfullyMessage, type: .success)
            )
        )

        VStack {
            Text("Success Top Toast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.pink)
        .topToast(
            .constant(
                Toast(message: Shared.soundSharedSuccessfullyMessage, type: .success)
            )
        )

        VStack {
            Text("Warning Toast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.pink)
        .toast(
            .constant(
                Toast(message: "Não foi possível ativar as notificações de episódios. Tente novamente.", type: .warning)
            )
        )

        VStack {
            Text("Wait Toast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.pink)
        .toast(
            .constant(
                Toast(message: String(format: Shared.Sync.waitMessage, "58 segundos"), type: .wait)
            )
        )

        VStack {
            Text("Thank You Toast")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .border(.pink)
        .toast(
            .constant(
                Toast(message: "Obrigado!", type: .thankYou)
            )
        )
    }
}
