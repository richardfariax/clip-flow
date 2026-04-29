import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    @ObservedObject var settings: AppSettings
    let closePanel: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            header
            searchField
            filterBar
            content
            keyboardHelp
        }
        .padding(16)
        .frame(width: 560, height: 700)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.16), value: viewModel.searchText)
        .animation(.easeInOut(duration: 0.16), value: viewModel.selectedItemID)
        .onAppear {
            viewModel.refresh()
        }
    }

    private var panelBackground: some View {
        VisualEffectBlur(material: .windowBackground, blendingMode: .withinWindow)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                BrandLogoView(size: 24, cornerRadius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text("ClipFlow")
                        .font(.title3.weight(.semibold))
                    Text("\(settings.hotkeyDisplay) · \(t("Enter para colar", "Press Enter to paste"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Text(displayedCountText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(t("Limpar", "Clear")) {
                viewModel.clearAll()
            }
            .buttonStyle(.bordered)

            Button {
                closePanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.callout.weight(.semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
        }
    }

    private var searchField: some View {
        TextField(t("Buscar por conteúdo ou app", "Search by content or app"), text: $viewModel.searchText)
            .textFieldStyle(.roundedBorder)
            .onSubmit {
                closePanel()
                viewModel.pasteSelectedItem()
            }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Text(t("Filtro", "Filter"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: filterBinding) {
                ForEach(ClipboardPanelFilter.allCases) { filter in
                    Text(filter.title(for: settings.language)).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Spacer(minLength: 0)

            if viewModel.activeFilter != .all {
                Button(t("Limpar filtro", "Clear filter")) {
                    viewModel.setFilter(.all)
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
    }

    private var content: some View {
        GroupBox {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.items) { item in
                            ClipboardCardView(
                                item: item,
                                isSelected: viewModel.selectedItemID == item.id,
                                language: settings.language,
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
                            .id(item.id)
                        }

                        if viewModel.items.isEmpty {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .onChange(of: viewModel.selectedItemID, initial: false) { _, selectedItemID in
                    guard let selectedItemID else { return }
                    withAnimation(.easeInOut(duration: 0.14)) {
                        proxy.scrollTo(selectedItemID, anchor: .center)
                    }
                }
            }
        }
        .groupBoxStyle(.automatic)
    }

    private var keyboardHelp: some View {
        HStack(spacing: 10) {
            Text("⌘1-5")
            Text("⌘D")
            Text("⌘P")
            Text("⌘C")
            Text("↑ ↓")
            Text("↩")
            Spacer(minLength: 0)
            Text(t("atalhos", "shortcuts"))
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            Text(t("Nenhum item no histórico", "No history items"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(t("Copie algo para começar", "Copy something to start"))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }

    private var displayedCountText: String {
        let total = viewModel.itemCount(for: .all)
        let filtered = viewModel.items.count
        if filtered == total {
            return "\(total) \(t("itens", "items"))"
        }
        return "\(filtered)/\(total) \(t("itens", "items"))"
    }

    private var filterBinding: Binding<ClipboardPanelFilter> {
        Binding(
            get: { viewModel.activeFilter },
            set: { viewModel.setFilter($0) }
        )
    }
}
