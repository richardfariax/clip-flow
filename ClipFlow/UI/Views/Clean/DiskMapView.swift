import SwiftUI

/// Lupa de Espaço no estilo CleanMyMac: bolhas proporcionais ao tamanho,
/// painel lateral com lista, navegação por pastas e remoção com revisão.
struct DiskMapView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: DiskMapService

    @State private var selected: Set<URL> = []
    @State private var confirmsRemoval = false

    var body: some View {
        VStack(spacing: 0) {
            breadcrumb
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

            HStack(spacing: 0) {
                sidebarPanel
                    .frame(width: 280)
                bubbleCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            CleanBottomBar(
                summary: selectionSummary,
                actionTitle: t("Revisar e Remover", "Review and Remove"),
                actionDisabled: selected.isEmpty,
                action: { confirmsRemoval = true }
            )
        }
        .onAppear {
            if service.root == nil && !service.isScanning { service.scan() }
        }
        .confirmationDialog(
            t("Mover \(selected.count) item(ns) para a Lixeira?",
              "Move \(selected.count) item(s) to the Trash?"),
            isPresented: $confirmsRemoval
        ) {
            Button(t("Mover para a Lixeira", "Move to Trash"), role: .destructive) {
                removeSelected()
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) {}
        }
    }

    // MARK: - Breadcrumb

    private var breadcrumb: some View {
        HStack(spacing: 8) {
            Button {
                navigate(to: service.currentURL.deletingLastPathComponent())
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(CleanGlassButtonStyle())
            .disabled(service.isScanning || service.currentURL.path == "/")

            HStack(spacing: 4) {
                Image(systemName: "folder.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                Text(displayPath)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(.white.opacity(0.1)))

            Button {
                service.scan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(CleanGlassButtonStyle())
            .disabled(service.isScanning)
        }
    }

    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = service.currentURL.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: - Painel lateral

    private var sidebarPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let root = service.root {
                VStack(alignment: .leading, spacing: 2) {
                    Text(root.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(CleanFormat.bytes(root.bytes) + "  ·  \(root.children.count) " + t("itens", "items"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(root.children) { node in
                            sidebarRow(node)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            } else if service.isScanning {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView(t("Medindo pastas…", "Measuring folders…"))
                        .tint(.white)
                    Spacer()
                }
                Spacer()
            } else {
                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.2))
    }

    private func sidebarRow(_ node: DiskNode) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: selectionBinding(node.url))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(FileSweeper.isProtected(node.url))
            Button {
                open(node)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.cyan.opacity(0.9))
                    Text(node.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(CleanFormat.bytes(node.bytes))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected.contains(node.url) ? .white.opacity(0.1) : .clear)
        )
    }

    // MARK: - Bolhas

    private var bubbleCanvas: some View {
        GeometryReader { proxy in
            let nodes = Array((service.root?.children ?? []).prefix(11))
            let bubbles = BubbleLayout.compute(
                nodes: nodes,
                in: CGSize(width: proxy.size.width, height: proxy.size.height)
            )
            ZStack {
                if service.isScanning {
                    ProgressView().tint(.white)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                } else {
                    ForEach(bubbles, id: \.node.id) { bubble in
                        bubbleView(bubble)
                            .position(bubble.center)
                    }
                }
            }
        }
        .padding(12)
    }

    private func bubbleView(_ bubble: BubbleLayout.Bubble) -> some View {
        let isSelected = selected.contains(bubble.node.url)
        return Button {
            open(bubble.node)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.06)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: bubble.radius * 2
                        )
                    )
                    .overlay(
                        Circle().strokeBorder(
                            isSelected ? Color(red: 0.91, green: 0.15, blue: 0.6) : .white.opacity(0.25),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                    )
                VStack(spacing: 3) {
                    Image(systemName: bubble.node.isDirectory ? "folder.fill" : "doc.fill")
                        .font(.system(size: min(bubble.radius * 0.42, 34)))
                        .foregroundStyle(.cyan)
                    if bubble.radius > 34 {
                        Text(bubble.node.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .frame(maxWidth: bubble.radius * 1.6)
                        Text(CleanFormat.bytes(bubble.node.bytes))
                            .font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: bubble.radius * 2, height: bubble.radius * 2)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(bubble.node.url.path + " — " + CleanFormat.bytes(bubble.node.bytes))
        .contextMenu {
            Button(t("Mostrar no Finder", "Reveal in Finder")) {
                FileSweeper.revealInFinder(bubble.node.url)
            }
            if !FileSweeper.isProtected(bubble.node.url) {
                Button(selected.contains(bubble.node.url)
                       ? t("Desmarcar", "Deselect")
                       : t("Selecionar para remoção", "Select for removal")) {
                    toggleSelection(bubble.node.url)
                }
            }
        }
    }

    // MARK: - Ações

    private func open(_ node: DiskNode) {
        guard node.isDirectory, !service.isScanning else { return }
        navigate(to: node.url)
    }

    private func navigate(to url: URL) {
        selected = []
        service.scan(url: url)
    }

    private func removeSelected() {
        _ = FileSweeper.trash(urls: Array(selected))
        selected = []
        service.scan()
    }

    private func toggleSelection(_ url: URL) {
        if selected.contains(url) { selected.remove(url) } else { selected.insert(url) }
    }

    private func selectionBinding(_ url: URL) -> Binding<Bool> {
        Binding(
            get: { selected.contains(url) },
            set: { isOn in
                if isOn { selected.insert(url) } else { selected.remove(url) }
            }
        )
    }

    private var selectionSummary: String {
        guard !selected.isEmpty else {
            return t("Nenhum item selecionado  |  0 KB", "No items selected  |  0 KB")
        }
        let bytes = (service.root?.children ?? [])
            .filter { selected.contains($0.url) }
            .reduce(UInt64(0)) { $0 + $1.bytes }
        return t("\(selected.count) selecionado(s)", "\(selected.count) selected")
            + "  |  " + CleanFormat.bytes(bytes)
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}

/// Empacotamento de círculos: maior no centro, demais em espiral ao redor.
enum BubbleLayout {
    struct Bubble {
        let node: DiskNode
        let center: CGPoint
        let radius: CGFloat
    }

    static func compute(nodes: [DiskNode], in size: CGSize) -> [Bubble] {
        guard !nodes.isEmpty, size.width > 60, size.height > 60 else { return [] }
        let total = nodes.reduce(Double(0)) { $0 + Double($1.bytes) }
        guard total > 0 else { return [] }

        // Área alvo ~42% do canvas; raio mínimo legível, máximo limitado.
        let targetArea = Double(size.width * size.height) * 0.42
        let scale = sqrt(targetArea / (.pi * total))
        let maxRadius = Double(min(size.width, size.height)) * 0.30
        let minRadius = 16.0

        var placed: [Bubble] = []
        let canvasCenter = CGPoint(x: size.width / 2, y: size.height / 2)

        for (index, node) in nodes.enumerated() {
            let radius = CGFloat(min(max(sqrt(Double(node.bytes)) * scale, minRadius), maxRadius))
            if index == 0 {
                placed.append(Bubble(node: node, center: canvasCenter, radius: radius))
                continue
            }

            // Busca em espiral a partir do centro até achar posição livre.
            var position: CGPoint?
            let golden = 2.39996
            var step = 0
            while position == nil && step < 2000 {
                let angle = Double(step) * golden * 0.12
                let distance = Double(step) * 0.55 + Double(placed[0].radius + radius)
                let candidate = CGPoint(
                    x: canvasCenter.x + CGFloat(cos(angle) * distance),
                    y: canvasCenter.y + CGFloat(sin(angle) * distance * 0.82)
                )
                let insideBounds = candidate.x - radius > 4 && candidate.x + radius < size.width - 4
                    && candidate.y - radius > 4 && candidate.y + radius < size.height - 4
                let collides = placed.contains { other in
                    let dx = other.center.x - candidate.x
                    let dy = other.center.y - candidate.y
                    return sqrt(Double(dx * dx + dy * dy)) < Double(other.radius + radius) + 6
                }
                if insideBounds && !collides {
                    position = candidate
                }
                step += 1
            }

            if let position {
                placed.append(Bubble(node: node, center: position, radius: radius))
            }
        }
        return placed
    }
}
