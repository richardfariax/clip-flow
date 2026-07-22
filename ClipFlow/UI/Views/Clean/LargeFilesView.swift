import SwiftUI

/// Grandes e Antigos: hero índigo com Scan e gerenciador claro com filtro.
struct LargeFilesView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: LargeOldFilesService

    private enum Screen {
        case hero
        case manager
    }

    @State private var screen: Screen = .hero
    @State private var selected: Set<URL> = []
    @State private var confirmsTrash = false

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .hero: hero
            case .manager: manager
            }
        }
        .confirmationDialog(
            t("Mover \(selected.count) arquivo(s) para a Lixeira?",
              "Move \(selected.count) file(s) to the Trash?"),
            isPresented: $confirmsTrash
        ) {
            Button(t("Mover para a Lixeira", "Move to Trash"), role: .destructive) {
                service.trash(urls: selected)
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
                title: t("Grandes e Antigos", "Large & Old"),
                leftAction: {}
            )

            Spacer()

            HStack(spacing: 40) {
                ZStack {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.38, blue: 0.95), Color(red: 0.18, green: 0.15, blue: 0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 170, height: 170)
                        .shadow(color: .indigo.opacity(0.5), radius: 26, y: 8)
                    Image(systemName: "externaldrive.fill")
                        .font(.system(size: 62, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(t("Grandes e Antigos", "Large & Old"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text(t("Encontre os maiores arquivos escondidos na sua\npasta pessoal e decida o que merece ficar.",
                           "Find the largest files hiding in your home folder\nand decide what deserves to stay."))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))

                    Picker("", selection: $service.threshold) {
                        ForEach(LargeOldFilesService.SizeThreshold.allCases) { threshold in
                            Text("≥ " + threshold.label).tag(threshold)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 330)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            Button {
                selected = []
                service.scan()
                withAnimation(.easeInOut(duration: 0.2)) { screen = .manager }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.55, green: 0.5, blue: 1.0), Color(red: 0.3, green: 0.25, blue: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: .indigo.opacity(0.55), radius: 16, y: 4)
                    Text(t("Analisar", "Scan"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 34)
        }
    }

    // MARK: - Manager (claro)

    private var manager: some View {
        ManagerSurface {
            VStack(spacing: 0) {
                CleanTopBar(
                    leftIcon: "chevron.left",
                    leftTitle: t("Voltar", "Back"),
                    title: t("Arquivos Grandes e Antigos", "Large & Old Files"),
                    leftAction: { withAnimation(.easeInOut(duration: 0.2)) { screen = .hero } }
                ) {
                    Button {
                        selected = []
                        service.scan()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(service.isScanning)
                }

                Divider()

                if service.isScanning {
                    Spacer()
                    ProgressView(t("Varrendo a pasta pessoal…", "Sweeping home folder…"))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(service.files) { file in
                                fileRow(file)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
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

    private func fileRow(_ file: CleanFileItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: selectionBinding(file.url))
                .toggleStyle(.checkbox)
                .labelsHidden()
            Image(systemName: "doc.fill")
                .font(.system(size: 13))
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name).font(.system(size: 12, weight: .medium))
                HStack(spacing: 6) {
                    Text(file.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let modified = file.modifiedAt {
                        Text("· " + modified.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CleanFormat.bytes(file.bytes))
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(.indigo)
            Button {
                FileSweeper.revealInFinder(file.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected.contains(file.url) ? Color(red: 0.93, green: 0.92, blue: 0.99) : Color.black.opacity(0.02))
        )
    }

    // MARK: - Helpers

    private var selectionSummary: String {
        guard !selected.isEmpty else {
            return "\(service.files.count) " + t("arquivos  |  ", "files  |  ") + CleanFormat.bytes(service.totalBytes)
        }
        let bytes = service.files.filter { selected.contains($0.url) }.reduce(UInt64(0)) { $0 + $1.bytes }
        return t("\(selected.count) Selecionado(s)", "\(selected.count) Selected") + "  |  " + CleanFormat.bytes(bytes)
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
