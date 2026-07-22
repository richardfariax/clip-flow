import SwiftUI

/// Análise Inteligente: botão único que roda detritos + proteção + inicialização.
struct SmartScanView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var junkService: JunkScanService
    @ObservedObject var protectionService: ProtectionService
    @ObservedObject var startupService: StartupItemsService
    let onOpenModule: (CleanModule) -> Void

    @State private var hasScanned = false
    @State private var confirmsCleanup = false

    private var isScanning: Bool {
        junkService.isScanning || protectionService.isScanning || startupService.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            CleanTopBar(
                leftIcon: "arrow.counterclockwise",
                leftTitle: t("Recomeçar", "Start Over"),
                title: t("Análise Inteligente", "Smart Scan"),
                leftAction: { runScan() }
            )

            ScrollView {
                VStack(spacing: 18) {
                    HeroHeadline(
                        text: headline,
                        pillTitle: nil,
                        pillAction: nil
                    )

                    scanButton

                    if hasScanned && !isScanning {
                        resultsGrid
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
        .confirmationDialog(
            t("Mover os detritos seguros para a Lixeira?", "Move safe junk to the Trash?"),
            isPresented: $confirmsCleanup
        ) {
            Button(t("Limpar itens seguros", "Clean safe items"), role: .destructive) {
                junkService.clean(ruleIDs: junkService.safeDefaultRuleIDs)
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) {}
        }
    }

    private var headline: String {
        if isScanning {
            return t("Analisando o seu Mac…", "Scanning your Mac…")
        }
        if hasScanned {
            return t("Análise concluída. Veja os resultados.", "Scan complete. Review your results.")
        }
        return t("Uma análise para cuidar de tudo:\ndetritos, proteção e inicialização.",
                 "One scan to care for everything:\njunk, protection and startup.")
    }

    private var scanButton: some View {
        Button {
            runScan()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.65, green: 0.35, blue: 1.0), Color(red: 0.35, green: 0.2, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .shadow(color: .purple.opacity(0.45), radius: 20, y: 6)
                if isScanning {
                    ProgressView().controlSize(.large).tint(.white)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .bold))
                        Text(hasScanned ? t("Reanalisar", "Rescan") : t("Analisar", "Scan"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
        .padding(.vertical, 8)
    }

    private var resultsGrid: some View {
        VStack(spacing: 10) {
            resultRow(
                module: .junk,
                title: t("Detritos encontrados", "Junk found"),
                value: CleanFormat.bytes(junkService.totalBytes),
                detail: t("\(junkService.rules.count) regras: caches, logs, dev, navegadores e apps",
                          "\(junkService.rules.count) rules: caches, logs, dev, browsers and apps")
            )
            resultRow(
                module: .protection,
                title: t("Itens para revisar", "Items to review"),
                value: "\(protectionService.findings.count)",
                detail: protectionService.warningCount > 0
                    ? t("\(protectionService.warningCount) com alerta", "\(protectionService.warningCount) flagged")
                    : t("Nenhum alerta crítico", "No critical flags")
            )
            resultRow(
                module: .speedup,
                title: t("Itens de inicialização", "Startup items"),
                value: "\(startupService.items.count)",
                detail: t("Agentes e daemons carregados no login",
                          "Agents and daemons loaded at login")
            )

            if junkService.safeBytes > 0 {
                Button {
                    confirmsCleanup = true
                } label: {
                    Label(
                        t("Limpar \(CleanFormat.bytes(junkService.safeBytes)) (itens seguros)",
                          "Clean \(CleanFormat.bytes(junkService.safeBytes)) (safe items)"),
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CleanCTAButtonStyle(tint: .purple))
                .disabled(junkService.isCleaning)
            }

            if let cleanup = junkService.lastCleanup {
                Text(t("Última limpeza liberou ", "Last cleanup reclaimed ") + CleanFormat.bytes(cleanup.reclaimedBytes))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
            }
        }
    }

    private func resultRow(module: CleanModule, title: String, value: String, detail: String) -> some View {
        Button {
            onOpenModule(module)
        } label: {
            CleanCard {
                HStack(spacing: 12) {
                    HeroCardIcon(systemImage: module.systemImage, tint: module.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text(value)
                        .font(.system(size: 16, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func runScan() {
        withAnimation(.easeInOut(duration: 0.2)) { hasScanned = true }
        junkService.scan()
        protectionService.scan()
        startupService.refresh()
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
