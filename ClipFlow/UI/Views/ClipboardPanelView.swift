import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    @ObservedObject var settings: AppSettings
    let closePanel: () -> Void

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 14) {
                header
                searchField
                content
            }
            .padding(18)
        }
        .frame(width: 560, height: 700)
        .animation(.easeInOut(duration: 0.16), value: viewModel.searchText)
        .animation(.easeInOut(duration: 0.16), value: viewModel.selectedItemID)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var panelBackground: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.02),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(red: 0.44, green: 0.54, blue: 0.92).opacity(0.20),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1.0)
        )
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                BrandLogoView(size: 28, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipFlow")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("\(settings.hotkeyDisplay) para abrir. Enter para colar.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Text("\(viewModel.items.count)")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.10)))

                Button("Limpar Tudo") {
                    viewModel.clearAll()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.0)
                        )
                )

                Button {
                    closePanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.20), lineWidth: 1.0))
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary.opacity(0.95))

            TextField("Buscar por conteúdo ou app", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))

            Spacer(minLength: 0)

            Text("↑ ↓")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.09)))

            Text("↩")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.09)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.items) { item in
                    ClipboardCardView(
                        item: item,
                        isSelected: viewModel.selectedItemID == item.id,
                        onPaste: {
                            closePanel()
                            viewModel.paste(item: item)
                        },
                        onSelect: {
                            viewModel.select(itemID: item.id)
                        },
                        onToggleFavorite: {
                            viewModel.toggleFavorite(itemID: item.id)
                        },
                        onTogglePin: {
                            viewModel.togglePin(itemID: item.id)
                        },
                        onDelete: {
                            viewModel.delete(itemID: item.id)
                        }
                    )
                }

                if viewModel.items.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Nenhum item no histórico")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Copie algo para começar")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}
