import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    @ObservedObject var settings: AppSettings
    let closePanel: () -> Void

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                searchField
                content
            }
            .padding(16)
        }
        .frame(width: 560, height: 700)
        .animation(.easeInOut(duration: 0.16), value: viewModel.searchText)
        .animation(.easeInOut(duration: 0.16), value: viewModel.selectedItemID)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image("ClipFlowLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                    Text("ClipFlow")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Text("\(settings.hotkeyDisplay) para abrir. Enter para colar.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Limpar Tudo") {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)

            Button {
                closePanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .padding(6)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar por conteúdo ou app", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
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
            .padding(.vertical, 4)
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
