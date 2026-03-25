import SwiftUI

struct GlassButton: View {

    let symbol: String?
    let title: String
    let color: Color
    let lightModeLabelColor: Color
    let fullWidth: Bool
    let compact: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    init(
        symbol: String? = nil,
        title: String,
        color: Color,
        lightModeLabelColor: Color? = nil,
        fullWidth: Bool = false,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.title = title
        self.color = color
        self.lightModeLabelColor = lightModeLabelColor ?? color
        self.fullWidth = fullWidth
        self.compact = compact
        self.action = action
    }

    private var isCTA: Bool { color != .clear }

    private var resolvedForeground: Color {
        if colorScheme == .dark { return .white }
        return isCTA ? lightModeLabelColor : .primary
    }

    var body: some View {
        if #available(iOS 26, *) {
            label
                .font(isCTA ? .body : .subheadline)
                .fontWeight(.regular)
                .foregroundStyle(resolvedForeground)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, .spacing(compact ? .xSmall : .medium))
                .padding(.horizontal, .spacing(.medium))
                .glassEffect(
                    .regular.tint(
                        colorScheme == .dark ? color.opacity(0.3) : color.opacity(0.1)
                    ).interactive()
                )
                .onTapGesture {
                    action()
                }
        } else if color == .clear {
            Button {
                action()
            } label: {
                label
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .padding(.vertical, .spacing(compact ? .xxxSmall : .xxSmall))
                    .frame(maxWidth: fullWidth ? .infinity : nil)
            }
            .foregroundColor(.blue)
        } else {
            Button {
                action()
            } label: {
                label
                    .font(.body)
                    .fontWeight(.regular)
                    .foregroundStyle(color)
                    .padding(.vertical, .spacing(compact ? .xxxSmall : .xxSmall))
                    .frame(maxWidth: fullWidth ? .infinity : nil)
            }
            .buttonStyle(.bordered)
            .tint(color)
        }
    }

    @ViewBuilder
    private var label: some View {
        if let symbol {
            Label(title, systemImage: symbol)
        } else {
            Text(title)
        }
    }
}

struct GlassIconButton: View {

    let symbol: String
    let color: Color
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if #available(iOS 26, *) {
            Image(systemName: symbol)
                .font(.subheadline)
                .fontWeight(.regular)
                .foregroundStyle(colorScheme == .dark ? .white : color)
                .padding(.spacing(.small))
                .glassEffect(
                    .regular.tint(
                        colorScheme == .dark ? color.opacity(0.3) : color.opacity(0.1)
                    ).interactive()
                )
                .onTapGesture {
                    action()
                }
        } else {
            Button {
                action()
            } label: {
                Image(systemName: symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            .buttonStyle(.bordered)
            .tint(color)
        }
    }
}

// MARK: - Previews

#Preview("With Symbol") {
    GlassButton(
        symbol: "bookmark.fill",
        title: "Marcar Esse Ponto",
        color: .red,
        action: {}
    )
    .padding()
}

#Preview("Text Only") {
    GlassButton(
        title: "Vamos lá",
        color: .green,
        action: {}
    )
    .padding()
}

#Preview("Icon Only") {
    GlassIconButton(
        symbol: "scissors",
        color: .orange,
        action: {}
    )
    .padding()
}
