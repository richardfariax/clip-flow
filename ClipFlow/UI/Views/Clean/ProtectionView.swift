import SwiftUI

/// Proteção: hero verde-menta com status e lista de achados em cards claros.
struct ProtectionView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: ProtectionService

    @State private var findingPendingQuarantine: ProtectionFinding?

    var body: some View {
        VStack(spacing: 0) {
            CleanTopBar(
                leftIcon: "arrow.counterclockwise",
                leftTitle: t("Recomeçar", "Start Over"),
                title: t("Proteção", "Protection"),
                leftAction: { service.scan() }
            )

            ScrollView {
                VStack(spacing: 18) {
                    HeroHeadline(
                        text: heroHeadline,
                        pillTitle: service.isScanning ? nil : t("Revisar Agora", "Review Now"),
                        pillAction: { service.scan() }
                    )

                    if service.isScanning {
                        ProgressView().controlSize(.large).tint(.white).padding(.top, 20)
                    } else if service.reviewedCount > 0 {
                        statusCard
                        VStack(spacing: 8) {
                            ForEach(service.findings) { finding in
                                findingRow(finding)
                            }
                        }
                    }

                    Text(t("Isto não é um antivírus: é uma revisão heurística de LaunchAgents e LaunchDaemons — o padrão mais comum de adware no macOS.",
                           "This is not an antivirus: it's a heuristic review of LaunchAgents and LaunchDaemons — the most common macOS adware pattern."))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            if service.reviewedCount == 0 && !service.isScanning { service.scan() }
        }
        .confirmationDialog(
            t("Mover o item para a Lixeira? Ele deixa de carregar no próximo login.",
              "Move this item to the Trash? It stops loading at next login."),
            isPresented: Binding(
                get: { findingPendingQuarantine != nil },
                set: { if !$0 { findingPendingQuarantine = nil } }
            )
        ) {
            Button(t("Mover para a Lixeira", "Move to Trash"), role: .destructive) {
                if let finding = findingPendingQuarantine { service.quarantine(finding) }
                findingPendingQuarantine = nil
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) { findingPendingQuarantine = nil }
        }
    }

    private var heroHeadline: String {
        if service.isScanning {
            return t("Revisando itens de inicialização…", "Reviewing startup items…")
        }
        if service.reviewedCount == 0 {
            return t("Revise itens suspeitos de inicialização.", "Review suspicious startup items.")
        }
        if service.warningCount == 0 {
            return t("Nenhum alerta em \(service.reviewedCount) itens revisados.",
                     "No flags across \(service.reviewedCount) reviewed items.")
        }
        return t("\(service.warningCount) alerta(s) em \(service.reviewedCount) itens revisados.",
                 "\(service.warningCount) flag(s) across \(service.reviewedCount) reviewed items.")
    }

    private var statusCard: some View {
        CleanCard(prominent: true) {
            HStack(spacing: 12) {
                Image(systemName: service.warningCount == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(service.warningCount == 0 ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.warningCount == 0
                         ? t("Tudo em ordem", "All clear")
                         : t("Itens para a sua atenção", "Items for your attention"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(t("\(service.findings.count) itens listados para revisão manual",
                           "\(service.findings.count) items listed for manual review"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }
        }
    }

    private func findingRow(_ finding: ProtectionFinding) -> some View {
        CleanCard {
            HStack(spacing: 12) {
                Image(systemName: finding.severity == .warning
                      ? "exclamationmark.triangle.fill"
                      : "questionmark.circle.fill")
                    .foregroundStyle(finding.severity == .warning ? .orange : .cyan)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(finding.item.label)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(settings.text(ptBR: finding.reasonPT, en: finding.reasonEN))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    if let program = finding.item.programPath {
                        Text(program)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer()
                Button {
                    FileSweeper.revealInFinder(finding.item.url)
                } label: {
                    Image(systemName: "magnifyingglass").font(.caption)
                }
                .buttonStyle(.borderless)
                .help(t("Mostrar no Finder", "Reveal in Finder"))

                if finding.item.isRemovable {
                    Button(role: .destructive) {
                        findingPendingQuarantine = finding
                    } label: {
                        Image(systemName: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help(t("Mover para a Lixeira", "Move to Trash"))
                } else {
                    Text(t("Requer admin", "Needs admin"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
