import SwiftUI

/// Limpeza fiel ao CleanMyMac: hero verde com cards por seção e
/// Gerenciador de Limpeza claro (master-detail) com seleção por item.
struct JunkCleanView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: JunkScanService

    private enum Screen {
        case hero
        case review
    }

    @State private var screen: Screen = .hero
    @State private var focusedRuleID: String?
    /// Seleção por item, agrupada por regra.
    @State private var selectedItems: [String: Set<URL>] = [:]
    @State private var appliedDefaultSelection = false
    @State private var confirmsCleanup = false
    @State private var pendingClean: [String: Set<URL>] = [:]

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .hero: hero
            case .review: reviewManager
            }
        }
        .onAppear {
            if service.results.isEmpty { service.scan { applyDefaultSelection() } }
            else if !appliedDefaultSelection { applyDefaultSelection() }
        }
        .confirmationDialog(confirmationMessage, isPresented: $confirmsCleanup) {
            Button(t("Limpar", "Clean Up"), role: .destructive) {
                service.clean(itemsByRule: pendingClean) { applyDefaultSelection() }
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
                title: t("Limpeza", "Cleanup"),
                leftAction: { service.scan { applyDefaultSelection() } }
            )

            ScrollView {
                VStack(spacing: 18) {
                    HeroHeadline(
                        text: heroHeadline,
                        pillTitle: service.isScanning ? nil : t("Revisar Todos os Detritos", "Review All Junk"),
                        pillAction: { openReview(rule: nil) }
                    )

                    if service.isScanning {
                        ProgressView().controlSize(.large).tint(.white).padding(.top, 30)
                    } else if service.totalBytes > 0 {
                        heroGrid
                    }

                    if let cleanup = service.lastCleanup {
                        Label(
                            t("Última limpeza liberou ", "Last cleanup reclaimed ")
                            + CleanFormat.bytes(cleanup.reclaimedBytes),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
    }

    private var heroHeadline: String {
        if service.isScanning {
            return t("Analisando o seu Mac…", "Scanning your Mac…")
        }
        if service.totalBytes == 0 {
            return t("Seu Mac está livre de detritos. Muito bem!",
                     "Your Mac is free of junk. Nice work!")
        }
        return t("Há \(CleanFormat.bytes(service.totalBytes)) de detritos no seu Mac.",
                 "There are \(CleanFormat.bytes(service.totalBytes)) of junk files on your Mac.")
    }

    /// Card grande do Sistema à esquerda + grade 2x2 das demais seções.
    private var heroGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            systemCard
                .frame(width: 300)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(secondarySections) { section in
                    sectionCard(section)
                }
            }
        }
    }

    private var secondarySections: [CleanupSection] {
        CleanupSection.allCases.filter { $0 != .system && service.bytes(in: $0) > 0 }
    }

    private var systemCard: some View {
        HeroCard(
            minHeight: 314,
            emphasized: true,
            reviewTitle: t("Revisar", "Review"),
            cleanTitle: service.safeBytes(in: .system) > 0 ? t("Limpar", "Clean") : nil,
            onReview: { openReview(section: .system) },
            onClean: { requestSectionClean(.system) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("\(CleanFormat.bytes(service.bytes(in: .system))) de Detritos do Sistema",
                       "\(CleanFormat.bytes(service.bytes(in: .system))) of System Junk Found"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(t("Limpe os arquivos desnecessários gerados pelo sistema e pelos seus aplicativos.",
                       "Clean up all of the unneeded files generated by your system and applications."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer(minLength: 10)

                HStack(spacing: 14) {
                    Spacer()
                    ForEach(["clock.badge.checkmark", "person.crop.circle.badge.checkmark", "doc.badge.gearshape"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func sectionCard(_ section: CleanupSection) -> some View {
        HeroCard(
            minHeight: 150,
            reviewTitle: t("Revisar", "Review"),
            cleanTitle: service.safeBytes(in: section) > 0 ? t("Limpar", "Clean") : nil,
            onReview: { openReview(section: section) },
            onClean: { requestSectionClean(section) }
        ) {
            HStack(alignment: .top) {
                Text(t("\(CleanFormat.bytes(service.bytes(in: section))) de \(section.title(t))",
                       "\(CleanFormat.bytes(service.bytes(in: section))) of \(section.title(t)) Found"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                HeroCardIcon(systemImage: section.systemImage, tint: sectionTint(section))
            }
        }
    }

    private func sectionTint(_ section: CleanupSection) -> Color {
        switch section {
        case .system: return .green
        case .browsers: return .blue
        case .developer: return .indigo
        case .apps: return .teal
        case .bigItems: return .orange
        }
    }

    // MARK: - Gerenciador de Limpeza (claro)

    private var reviewManager: some View {
        ManagerSurface {
            VStack(spacing: 0) {
                CleanTopBar(
                    leftIcon: "chevron.left",
                    leftTitle: t("Voltar", "Back"),
                    title: t("Gerenciador de Limpeza", "Cleanup Manager"),
                    leftAction: { withAnimation(.easeInOut(duration: 0.2)) { screen = .hero } }
                )

                Divider()

                HStack(spacing: 0) {
                    managerSidebar
                        .frame(width: 270)
                    Divider()
                    managerDetail
                        .frame(maxWidth: .infinity)
                }

                ManagerBottomBar(
                    summary: selectionSummary,
                    actionTitle: t("Limpar", "Clean Up"),
                    actionDisabled: totalSelectedCount == 0 || service.isCleaning || service.isScanning,
                    action: {
                        pendingClean = selectedItems
                        confirmsCleanup = true
                    }
                )
            }
        }
    }

    private var managerSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Detritos do Mac", "Mac Junk"))
                        .font(.system(size: 15, weight: .bold))
                    Text(t("Arquivos redundantes que ocupam espaço e atrapalham o desempenho.",
                           "Redundant files that clog up storage and impede performance."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

                ForEach(CleanupSection.allCases) { section in
                    let rules = visibleRules(in: section)
                    if !rules.isEmpty {
                        Text(section.title(t).uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                        ForEach(rules) { rule in
                            ManagerSidebarRow(
                                icon: rule.systemImage,
                                iconTint: rule.safety == .safe ? .green : .orange,
                                title: settings.text(ptBR: rule.titlePT, en: rule.titleEN),
                                badge: CleanFormat.bytes(service.bytes(forRule: rule.id)),
                                isSelected: focusedRuleID == rule.id,
                                action: { focusedRuleID = rule.id }
                            )
                            .padding(.horizontal, 6)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var managerDetail: some View {
        if let ruleID = focusedRuleID,
           let rule = service.rule(withID: ruleID),
           let result = service.results[ruleID] {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(settings.text(ptBR: rule.titlePT, en: rule.titleEN))
                            .font(.system(size: 16, weight: .bold))
                        safetyBadge(rule.safety)
                    }
                    Text(settings.text(ptBR: rule.detailPT, en: rule.detailEN))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(t("Selecionar:", "Select:"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(t("Tudo", "All")) {
                            selectedItems[ruleID] = Set(result.items.map(\.url))
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.91, green: 0.15, blue: 0.60))
                        Text("·").foregroundStyle(.secondary)
                        Button(t("Nada", "None")) {
                            selectedItems[ruleID] = []
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.91, green: 0.15, blue: 0.60))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(result.items) { item in
                            managerItemRow(item, rule: rule)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text(t("Selecione uma categoria à esquerda.", "Select a category on the left."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func managerItemRow(_ item: CleanFileItem, rule: CleanupRule) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: itemBinding(rule.id, item.url))
                .toggleStyle(.checkbox)
                .labelsHidden()
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 0.95))
            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(CleanFormat.bytes(item.bytes))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
            Button {
                FileSweeper.revealInFinder(item.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            .help(t("Mostrar no Finder", "Reveal in Finder"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isItemSelected(rule.id, item.url) ? Color(red: 0.95, green: 0.93, blue: 0.99) : .clear)
        )
    }

    private func safetyBadge(_ safety: CleanupSafety) -> some View {
        Text(safety == .safe ? t("Seguro", "Safe") : t("Revisar", "Review"))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(safety == .safe ? Color.green.opacity(0.15) : Color.orange.opacity(0.15)))
            .foregroundStyle(safety == .safe ? Color.green : Color.orange)
    }

    // MARK: - Navegação e seleção

    private func openReview(rule: CleanupRule? = nil, section: CleanupSection? = nil) {
        if let rule {
            focusedRuleID = rule.id
        } else if let section {
            focusedRuleID = visibleRules(in: section).first?.id
        } else {
            focusedRuleID = service.rules.first { service.bytes(forRule: $0.id) > 0 }?.id
        }
        withAnimation(.easeInOut(duration: 0.2)) { screen = .review }
    }

    private func requestSectionClean(_ section: CleanupSection) {
        var pending: [String: Set<URL>] = [:]
        for id in service.safeRuleIDs(in: section) {
            pending[id] = Set((service.results[id]?.items ?? []).map(\.url))
        }
        pendingClean = pending
        confirmsCleanup = true
    }

    private func visibleRules(in section: CleanupSection) -> [CleanupRule] {
        service.rules.filter { $0.section == section && service.bytes(forRule: $0.id) > 0 }
    }

    /// Pré-seleciona todos os itens das regras seguras.
    private func applyDefaultSelection() {
        var defaults: [String: Set<URL>] = [:]
        for id in service.safeDefaultRuleIDs {
            defaults[id] = Set((service.results[id]?.items ?? []).map(\.url))
        }
        selectedItems = defaults
        appliedDefaultSelection = true
    }

    private func isItemSelected(_ ruleID: String, _ url: URL) -> Bool {
        selectedItems[ruleID]?.contains(url) ?? false
    }

    private func itemBinding(_ ruleID: String, _ url: URL) -> Binding<Bool> {
        Binding(
            get: { selectedItems[ruleID]?.contains(url) ?? false },
            set: { isOn in
                var set = selectedItems[ruleID] ?? []
                if isOn { set.insert(url) } else { set.remove(url) }
                selectedItems[ruleID] = set
            }
        )
    }

    private var totalSelectedCount: Int {
        selectedItems.values.reduce(0) { $0 + $1.count }
    }

    private var totalSelectedBytes: UInt64 {
        var total: UInt64 = 0
        for (ruleID, urls) in selectedItems {
            guard let items = service.results[ruleID]?.items else { continue }
            total += items.filter { urls.contains($0.url) }.reduce(0) { $0 + $1.bytes }
        }
        return total
    }

    private var selectionSummary: String {
        t("\(totalSelectedCount) Itens Selecionados", "\(totalSelectedCount) Items Selected")
            + "  |  " + CleanFormat.bytes(totalSelectedBytes)
    }

    private var confirmationMessage: String {
        let hasPermanent = pendingClean.keys.contains { service.rule(withID: $0)?.deletesPermanently == true }
        return hasPermanent
            ? t("Itens da Lixeira serão apagados em definitivo. Os demais vão para a Lixeira. Continuar?",
                "Trash items will be permanently deleted. Everything else moves to the Trash. Continue?")
            : t("Os itens selecionados serão movidos para a Lixeira. Continuar?",
                "Selected items will be moved to the Trash. Continue?")
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
