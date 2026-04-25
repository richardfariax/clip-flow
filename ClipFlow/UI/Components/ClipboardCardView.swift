import SwiftUI

struct ClipboardCardView: View {
    let item: DecodedClipboardItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false
    private let cardCornerRadius: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            contentView
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                actionPill(title: item.isFavorite ? "Favorito" : "Favoritar", icon: item.isFavorite ? "star.fill" : "star", isCritical: false) {
                    onToggleFavorite()
                }

                actionPill(title: item.isPinned ? "Fixado" : "Fixar", icon: item.isPinned ? "pin.fill" : "pin", isCritical: false) {
                    onTogglePin()
                }

                Spacer(minLength: 0)

                actionPill(title: "Excluir", icon: "trash", isCritical: true) {
                    onDelete()
                }
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .onTapGesture {
            onSelect()
            onPaste()
        }
        .scaleEffect(isHovering ? 1.005 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isHovering)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                onSelect()
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(isSelected ? 0.16 : 0.11))
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.16),
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.6 : 1.0)
            )
            .compositingGroup()
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.95)
        }
        return Color.white.opacity(isHovering ? 0.30 : 0.15)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: leadingIconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(titleText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 8)

            if item.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var leadingIconName: String {
        switch item.kind {
        case .text:
            switch item.textSubtype {
            case .url:
                return "link"
            case .email:
                return "envelope"
            case .code:
                return "chevron.left.forwardslash.chevron.right"
            case .longText:
                return "doc.text"
            case .plain, .none:
                return "text.alignleft"
            }
        case .image:
            return "photo"
        }
    }

    private var titleText: String {
        switch item.kind {
        case .text:
            return item.text ?? "Texto indisponível"
        case .image:
            return "Imagem copiada"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "Conteúdo indisponível")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .lineLimit(4)
                .foregroundStyle(.primary)
        case .image:
            if let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text("Imagem indisponível")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionPill(title: String, icon: String, isCritical: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(isCritical ? Color.red.opacity(0.92) : Color.primary)
                .background(
                    Capsule(style: .continuous)
                        .fill(isCritical ? Color.red.opacity(0.11) : Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }
}
