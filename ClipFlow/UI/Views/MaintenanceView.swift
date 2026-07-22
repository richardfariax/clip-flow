import SwiftUI

struct MaintenanceView: View {
    @ObservedObject var metrics: SystemMetricsService
    @ObservedObject var settings: AppSettings
    @StateObject private var service = CacheMaintenanceService()
    @State private var selected: Set<CacheCategory> = [.applicationCaches, .developerBuilds]
    @State private var confirmsCleanup = false

    var body: some View {
        Form {
            Section {
                memoryGuidance
            }

            Section {
                ForEach(CacheCategory.allCases) { category in
                    Toggle(isOn: selectionBinding(category)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(categoryTitle(category)).font(.subheadline.weight(.medium))
                                Text(categoryDescription(category)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(size(for: category))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                    }
                    .toggleStyle(.checkbox)
                }

                if service.isScanning || service.isCleaning {
                    ProgressView(
                        service.isScanning
                            ? t("Analisando…", "Scanning…")
                            : t("Movendo para a Lixeira…", "Moving to Trash…")
                    )
                        .controlSize(.small)
                }

                HStack {
                    Button(t("Mover selecionados para a Lixeira", "Move selected to Trash"), role: .destructive) {
                        confirmsCleanup = true
                    }
                    .disabled(selected.isEmpty || service.results.isEmpty || service.isScanning || service.isCleaning)

                    Spacer()
                    if let lastCleanup = service.lastCleanup {
                        Text(t("Liberados: ", "Reclaimed: ") + bytes(lastCleanup.reclaimedBytes))
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if let error = service.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.orange).lineLimit(4)
                }
            } header: {
                HStack {
                    Label(t("Limpeza recuperável", "Recoverable cleanup"), systemImage: "sparkles")
                    Spacer()
                    Button(t("Analisar", "Scan")) { service.scan() }
                        .disabled(service.isScanning || service.isCleaning)
                }
            } footer: {
                Text(t(
                    "Nada é apagado permanentemente: os itens vão para a Lixeira. Apps podem recriar caches quando necessário.",
                    "Nothing is permanently deleted: items go to Trash. Apps may recreate caches when needed."
                ))
            }
        }
        .clipFlowSettingsFormStyle()
        .onAppear { if service.results.isEmpty { service.scan() } }
        .alert(t("Confirmar limpeza", "Confirm cleanup"), isPresented: $confirmsCleanup) {
            Button(t("Cancelar", "Cancel"), role: .cancel) {}
            Button(t("Mover para a Lixeira", "Move to Trash"), role: .destructive) {
                service.moveToTrash(categories: selected)
            }
        } message: {
            Text(t(
                "Apps abertos podem precisar recriar seus caches. Nenhum processo será encerrado.",
                "Open apps may need to recreate their caches. No process will be terminated."
            ))
        }
    }

    private var memoryGuidance: some View {
        let memory = metrics.snapshot.memory
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(t("Memória inteligente", "Smart memory"), systemImage: "memorychip")
                    .font(.headline)
                Spacer()
                Text(memory.usedFraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.title3.monospacedDigit().weight(.semibold))
            }
            ProgressView(value: memory.usedFraction)
            Text(memoryRecommendation(memory))
                .font(.subheadline)
                .foregroundStyle(memory.swapUsedBytes > 0 ? .orange : .secondary)
            Text(t(
                "O macOS usa RAM livre como cache para acelerar o sistema. O ClipFlow não executa purge nem encerra processos; ele mostra pressão, compressão e swap para orientar ações seguras.",
                "macOS uses free RAM as cache to speed up the system. ClipFlow never purges memory or terminates processes; it reports pressure, compression, and swap to guide safe action."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func memoryRecommendation(_ memory: MemoryUsage) -> String {
        if memory.swapUsedBytes > 2_000_000_000 {
            return t("Swap elevado. Feche apenas apps pesados que você não está usando.", "Swap is high. Close only heavy apps you are not using.")
        }
        if memory.usedFraction > 0.9 {
            return t("Uso alto, mas ainda gerenciado pelo macOS. Observe se o swap continua crescendo.", "Usage is high but managed by macOS. Watch whether swap keeps growing.")
        }
        return t("Memória saudável. Nenhuma otimização invasiva é necessária.", "Memory is healthy. No invasive optimization is needed.")
    }

    private func selectionBinding(_ category: CacheCategory) -> Binding<Bool> {
        Binding(
            get: { selected.contains(category) },
            set: { value in
                if value {
                    selected.insert(category)
                } else {
                    selected.remove(category)
                }
            }
        )
    }

    private func size(for category: CacheCategory) -> String {
        guard let result = service.results[category] else { return "—" }
        return bytes(result.bytes)
    }

    private func categoryTitle(_ category: CacheCategory) -> String {
        switch category {
        case .applicationCaches: t("Caches de aplicativos", "Application caches")
        case .developerBuilds: t("Builds do Xcode", "Xcode builds")
        case .logs: t("Logs do usuário", "User logs")
        }
    }

    private func categoryDescription(_ category: CacheCategory) -> String {
        switch category {
        case .applicationCaches: t("Dados temporários recriáveis", "Re-creatable temporary data")
        case .developerBuilds: t("DerivedData de projetos", "Project DerivedData")
        case .logs: t("Registros locais de diagnóstico", "Local diagnostic records")
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: value), countStyle: .file)
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
