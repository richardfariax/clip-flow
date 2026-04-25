import SwiftUI

struct ClipboardCardView: View {
    let item: DecodedClipboardItem
    let isSelected: Bool
    let language: AppLanguage
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
                actionPill(
                    title: item.isFavorite ? t("Favorito", "Favorite") : t("Favoritar", "Favorite"),
                    icon: item.isFavorite ? "star.fill" : "star",
                    isCritical: false
                ) {
                    onToggleFavorite()
                }

                actionPill(
                    title: item.isPinned ? t("Fixado", "Pinned") : t("Fixar", "Pin"),
                    icon: item.isPinned ? "pin.fill" : "pin",
                    isCritical: false
                ) {
                    onTogglePin()
                }

                Spacer(minLength: 0)

                actionPill(title: t("Excluir", "Delete"), icon: "trash", isCritical: true) {
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
        .animation(.easeInOut(duration: 0.16), value: isHovering)
        .animation(.easeInOut(duration: 0.16), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                onSelect()
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color.white.opacity(isSelected ? 0.14 : 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.3 : 1.0)
            )
    }

    private var borderColor: Color {
        if isSelected {
            return Color.white.opacity(0.55)
        }
        return Color.white.opacity(isHovering ? 0.30 : 0.18)
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
            return item.text ?? t("Texto indisponível", "Unavailable text")
        case .image:
            return t("Imagem copiada", "Copied image")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? t("Conteúdo indisponível", "Unavailable content"))
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
                Text(t("Imagem indisponível", "Unavailable image"))
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

    private func t(_ pt: String, _ en: String) -> String {
        language.text(ptBR: pt, en: en)
    }
}
