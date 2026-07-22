import AppKit
import SwiftUI
import ImageIO

/// "Meu Acúmulo" fiel ao CleanMyMac: hero teal com recomendações e
/// gerenciador claro com duplicatas e imagens similares.
struct DuplicatesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: DuplicateFinderService
    @ObservedObject var similarService: SimilarImagesService

    private enum Screen {
        case hero
        case manager
    }

    private enum Category: String, CaseIterable, Identifiable {
        case duplicates
        case similars
        var id: String { rawValue }
    }

    @State private var screen: Screen = .hero
    @State private var category: Category = .duplicates
    @State private var selected: Set<URL> = []
    @State private var confirmsTrash = false

    private var isScanning: Bool { service.isScanning || similarService.isScanning }

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .hero: hero
            case .manager: manager
            }
        }
        .onAppear {
            if service.groups.isEmpty && service.scannedFileCount == 0 && !isScanning {
                service.scan()
                similarService.scan()
            }
        }
        .confirmationDialog(
            t("Mover \(selected.count) arquivo(s) para a Lixeira?",
              "Move \(selected.count) file(s) to the Trash?"),
            isPresented: $confirmsTrash
        ) {
            Button(t("Remover", "Remove"), role: .destructive) {
                service.trash(urls: selected)
                similarService.trash(urls: selected)
                selected = []
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) {}
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            CleanTopBar(
                leftIcon: "arrow.counterclockwise",
                leftTitle: t("Recomeçar", "Start Over"),
                title: t("Meu Acúmulo", "My Clutter"),
                leftAction: {
                    selected = []
                    service.scan()
                    similarService.scan()
                }
            )

            ScrollView {
                VStack(spacing: 18) {
                    HeroHeadline(
                        text: heroHeadline,
                        pillTitle: isScanning ? nil : t("Revisar Todos os Arquivos", "Review All Files"),
                        pillAction: { openManager(.duplicates) }
                    )

                    if isScanning {
                        ProgressView().controlSize(.large).tint(.white).padding(.top, 30)
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            duplicatesCard
                                .frame(width: 300)
                            similarsCard
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
    }

    private var heroHeadline: String {
        if isScanning {
            return t("Vasculhando seus arquivos…", "Sorting through your files…")
        }
        let count = service.groups.flatMap(\.items).count + similarService.groups.flatMap(\.items).count
        if count == 0 {
            return t("Nenhum acúmulo por aqui. Impecável!", "No clutter here. Spotless!")
        }
        return t("Você tem \(count) arquivos para revisar.\nUse as recomendações ou revise manualmente.",
                 "You have \(count) files to sort through.\nUse quick recommendations or review them by hand.")
    }

    private var duplicatesCard: some View {
        HeroCard(
            minHeight: 250,
            emphasized: true,
            reviewTitle: t("Revisar", "Review"),
            onReview: { openManager(.duplicates) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("\(service.groups.count) Grupos de Duplicatas",
                       "\(service.groups.count) Fresh Duplicates Found"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(t("Remova \(CleanFormat.bytes(service.totalWastedBytes)) de arquivos duplicados.",
                       "Remove \(CleanFormat.bytes(service.totalWastedBytes)) of duplicate files."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer(minLength: 8)

                HStack(spacing: 10) {
                    Spacer()
                    ForEach(Array(previewDuplicateItems.prefix(3)), id: \.url) { item in
                        ImageThumbnail(url: item.url)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var previewDuplicateItems: [CleanFileItem] {
        service.groups.flatMap { $0.items.prefix(1) }
    }

    private var similarsCard: some View {
        HeroCard(
            minHeight: 250,
            reviewTitle: t("Revisar", "Review"),
            onReview: { openManager(.similars) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("\(similarService.groups.count) Grupos de Similares",
                               "\(similarService.groups.count) Similars Found"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(t("Você pode remover até \(CleanFormat.bytes(similarService.totalWastedBytes)) de imagens repetidas.",
                               "You may want to remove up to \(CleanFormat.bytes(similarService.totalWastedBytes)) of unneeded images."))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    HStack(spacing: -14) {
                        let preview = Array(similarService.groups.prefix(1).flatMap { $0.items.prefix(3) })
                        ForEach(preview.indices, id: \.self) { index in
                            ImageThumbnail(url: preview[index].url)
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.4), lineWidth: 1))
                                .rotationEffect(.degrees([-6.0, 3.0, 8.0][index % 3]))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Manager (claro)

    private var manager: some View {
        ManagerSurface {
            VStack(spacing: 0) {
                CleanTopBar(
                    leftIcon: "chevron.left",
                    leftTitle: t("Voltar", "Back"),
                    title: t("Gerenciador do Acúmulo", "My Clutter Manager"),
                    leftAction: { withAnimation(.easeInOut(duration: 0.2)) { screen = .hero } }
                ) {
                    Button(t("Seleção inteligente", "Smart select")) {
                        autoSelect()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }

                Divider()

                HStack(spacing: 0) {
                    managerSidebar
                        .frame(width: 250)
                    Divider()
                    managerDetail
                        .frame(maxWidth: .infinity)
                }

                ManagerBottomBar(
                    summary: selectionSummary,
                    actionTitle: t("Remover", "Remove"),
                    actionDisabled: selected.isEmpty,
                    action: { confirmsTrash = true }
                )
            }
        }
    }

    private var managerSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ManagerSidebarRow(
                icon: "doc.on.doc.fill",
                iconTint: .teal,
                title: t("Duplicatas", "Duplicates"),
                badge: "\(service.groups.count)",
                isSelected: category == .duplicates,
                action: { category = .duplicates }
            )
            .padding(.horizontal, 6)
            ManagerSidebarRow(
                icon: "photo.on.rectangle.angled",
                iconTint: .teal,
                title: t("Imagens similares", "Similar images"),
                badge: "\(similarService.groups.count)",
                isSelected: category == .similars,
                action: { category = .similars }
            )
            .padding(.horizontal, 6)
            Spacer()

            Text(t("Varre Mesa, Downloads, Documentos e Imagens. A biblioteca do Photos não é tocada.",
                   "Scans Desktop, Downloads, Documents and Pictures. The Photos library is untouched."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(12)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var managerDetail: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch category {
                case .duplicates:
                    if service.groups.isEmpty {
                        emptyState(t("Nenhuma duplicata entre \(service.scannedFileCount) arquivos.",
                                     "No duplicates among \(service.scannedFileCount) files."))
                    }
                    ForEach(service.groups) { group in
                        groupCard(
                            title: "\(group.items.count) " + t("cópias idênticas", "identical copies"),
                            waste: group.wastedBytes,
                            items: group.items,
                            keeperLabel: t("mais recente", "newest"),
                            showThumbs: false
                        )
                    }
                case .similars:
                    if similarService.groups.isEmpty {
                        emptyState(t("Nenhuma imagem similar entre \(similarService.scannedCount) analisadas.",
                                     "No similar images among \(similarService.scannedCount) scanned."))
                    }
                    ForEach(similarService.groups) { group in
                        groupCard(
                            title: "\(group.items.count) " + t("imagens parecidas", "similar images"),
                            waste: group.wastedBytes,
                            items: group.items,
                            keeperLabel: t("melhor qualidade", "best quality"),
                            showThumbs: true
                        )
                    }
                }
            }
            .padding(14)
        }
    }

    private func emptyState(_ message: String) -> some View {
        HStack {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            Text(message).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.03)))
    }

    private func groupCard(
        title: String,
        waste: UInt64,
        items: [CleanFileItem],
        keeperLabel: String,
        showThumbs: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Spacer()
                Text(t("Recuperável: ", "Reclaimable: ") + CleanFormat.bytes(waste))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.teal)
            }

            if showThumbs {
                HStack(spacing: 8) {
                    ForEach(items.prefix(6)) { item in
                        ImageThumbnail(url: item.url)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        selected.contains(item.url) ? Color.teal : Color.black.opacity(0.1),
                                        lineWidth: selected.contains(item.url) ? 2 : 1
                                    )
                            )
                    }
                }
            }

            Divider()

            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                HStack(spacing: 8) {
                    Toggle("", isOn: selectionBinding(item.url))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(item.name).font(.system(size: 11.5, weight: .medium))
                            if index == 0 {
                                Text(keeperLabel)
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.green.opacity(0.15)))
                                    .foregroundStyle(.green)
                            }
                        }
                        Text(item.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Text(CleanFormat.bytes(item.bytes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button {
                        FileSweeper.revealInFinder(item.url)
                    } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.black.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Helpers

    private func openManager(_ value: Category) {
        category = value
        withAnimation(.easeInOut(duration: 0.2)) { screen = .manager }
    }

    /// Marca tudo menos a primeira cópia (mais recente/melhor) de cada grupo.
    private func autoSelect() {
        var newSelection: Set<URL> = []
        for group in service.groups {
            for item in group.items.dropFirst() { newSelection.insert(item.url) }
        }
        for group in similarService.groups {
            for item in group.items.dropFirst() { newSelection.insert(item.url) }
        }
        selected = newSelection
    }

    private var selectionSummary: String {
        guard !selected.isEmpty else {
            return t("Nenhum Item Selecionado  |  0 KB", "No Items Selected  |  0 KB")
        }
        let all = service.groups.flatMap(\.items) + similarService.groups.flatMap(\.items)
        var seen = Set<URL>()
        var bytes: UInt64 = 0
        for item in all where selected.contains(item.url) && !seen.contains(item.url) {
            seen.insert(item.url)
            bytes += item.bytes
        }
        return t("\(selected.count) Selecionado(s)", "\(selected.count) Selected")
            + "  |  " + CleanFormat.bytes(bytes)
    }

    private func selectionBinding(_ url: URL) -> Binding<Bool> {
        Binding(
            get: { selected.contains(url) },
            set: { isOn in
                if isOn { selected.insert(url) } else { selected.remove(url) }
            }
        )
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}

/// Thumbnail leve carregada fora da main thread via ImageIO.
struct ImageThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.gray.opacity(0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.gray.opacity(0.5))
                    )
            }
        }
        .task(id: url) {
            let target = url
            let loaded = await Task.detached(priority: .utility) { () -> NSImage? in
                guard let source = CGImageSourceCreateWithURL(target as CFURL, nil) else { return nil }
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 128,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                    return nil
                }
                return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            }.value
            image = loaded
        }
    }
}
