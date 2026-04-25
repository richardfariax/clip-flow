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

    var body: some View {
        Button(action: onPaste) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: leadingIconName)
                        .font(.system(size: 12, weight: .semibold))

                    Text(titleText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    if item.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                contentView
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    actionPill(title: item.isFavorite ? "Favorito" : "Favoritar", icon: item.isFavorite ? "star.fill" : "star") {
                        onToggleFavorite()
                    }

                    actionPill(title: item.isPinned ? "Fixado" : "Fixar", icon: item.isPinned ? "pin.fill" : "pin") {
                        onTogglePin()
                    }

                    Spacer()

                    actionPill(title: "Excluir", icon: "trash") {
                        onDelete()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: isSelected ? 1.4 : 1.0)
                    )
                    .shadow(color: Color.black.opacity(isHovering ? 0.25 : 0.15), radius: isHovering ? 14 : 8, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect((isHovering || isSelected) ? 1.01 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isHovering)
        .animation(.spring(response: 0.20, dampingFraction: 0.84), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                onSelect()
            }
        }
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.75)
        }
        return Color.white.opacity(isHovering ? 0.35 : 0.18)
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

    private func actionPill(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }
}
