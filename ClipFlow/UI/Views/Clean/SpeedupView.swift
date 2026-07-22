import SwiftUI

/// Desempenho fiel ao CleanMyMac: hero laranja com recomendações e
/// Gerenciador de Desempenho claro (tarefas, inicialização, processos).
struct SpeedupView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: StartupItemsService
    @ObservedObject var maintenance: MaintenanceService

    private enum Screen {
        case hero
        case manager
    }

    private enum ManagerCategory: String, CaseIterable, Identifiable {
        case tasks
        case startup
        case processes
        var id: String { rawValue }
    }

    @State private var screen: Screen = .hero
    @State private var category: ManagerCategory = .tasks
    @State private var selectedTasks: Set<String> = []
    @State private var appliedDefaultTasks = false
    @State private var itemPendingRemoval: StartupItem?

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .hero: hero
            case .manager: manager
            }
        }
        .onAppear {
            if !appliedDefaultTasks {
                selectedTasks = Set(maintenance.tasks.map(\.id))
                appliedDefaultTasks = true
            }
            if service.items.isEmpty { service.refresh() }
        }
        .confirmationDialog(
            t("Mover o item de inicialização para a Lixeira? Ele deixa de carregar no próximo login.",
              "Move this startup item to the Trash? It stops loading at next login."),
            isPresented: Binding(
                get: { itemPendingRemoval != nil },
                set: { if !$0 { itemPendingRemoval = nil } }
            )
        ) {
            Button(t("Remover", "Remove"), role: .destructive) {
                if let item = itemPendingRemoval { service.remove(item) }
                itemPendingRemoval = nil
            }
            Button(t("Cancelar", "Cancel"), role: .cancel) { itemPendingRemoval = nil }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            CleanTopBar(
                leftIcon: "arrow.counterclockwise",
                leftTitle: t("Recomeçar", "Start Over"),
                title: t("Desempenho", "Performance"),
                leftAction: { service.refresh() }
            )

            ScrollView {
                VStack(spacing: 18) {
                    HeroHeadline(
                        text: t("Aplique recomendações selecionadas\nou execute tarefas de desempenho.",
                                "Apply curated recommendations\nor run performance tasks manually."),
                        pillTitle: t("Ver Todas as Tarefas", "View All Tasks"),
                        pillAction: { openManager(.tasks) }
                    )

                    HStack(alignment: .top, spacing: 14) {
                        tasksCard
                            .frame(width: 300)
                        VStack(spacing: 14) {
                            startupHeroCard
                            processesHeroCard
                        }
                    }

                    if let pt = maintenance.lastOutcomePT, let en = maintenance.lastOutcomeEN {
                        Label(settings.text(ptBR: pt, en: en), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
    }

    private var tasksCard: some View {
        HeroCard(
            minHeight: 314,
            emphasized: true,
            reviewTitle: t("Revisar", "Review"),
            cleanTitle: t("Executar", "Run Tasks"),
            onReview: { openManager(.tasks) },
            onClean: { maintenance.run(taskIDs: selectedTasks) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("\(maintenance.tasks.count) Tarefas de Manutenção Recomendadas",
                       "\(maintenance.tasks.count) Maintenance Tasks Recommended"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text(t("Seu coquetel semanal de manutenção está pronto. Execute as tarefas para manter o Mac em forma.",
                       "Your weekly maintenance cocktail is ready to be served! Run these tasks to keep your Mac in shape."))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Spacer(minLength: 10)

                HStack(spacing: 14) {
                    Spacer()
                    ForEach(Array(maintenance.tasks.prefix(3))) { task in
                        Image(systemName: task.systemImage)
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(.orange.opacity(0.35)))
                    }
                    Spacer()
                }
                .padding(.bottom, 10)

                if maintenance.isRunning {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small).tint(.white)
                        Spacer()
                    }
                }
            }
        }
    }

    private var startupHeroCard: some View {
        HeroCard(
            minHeight: 150,
            reviewTitle: t("Revisar", "Review"),
            onReview: { openManager(.startup) }
        ) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("Você tem \(service.items.count) itens de inicialização",
                           "You have \(service.items.count) startup items"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(t("Revise os agentes que abrem automaticamente ao ligar o Mac.",
                           "Review the agents that open automatically when you start up your Mac."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HeroCardIcon(systemImage: "power", tint: .red)
            }
        }
    }

    private var processesHeroCard: some View {
        HeroCard(
            minHeight: 150,
            reviewTitle: t("Revisar", "Review"),
            onReview: { openManager(.processes) }
        ) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("\(service.processes.count) processos em atividade",
                           "\(service.processes.count) background items found"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(t("Veja o que está consumindo CPU e memória agora.",
                           "See what's consuming CPU and memory right now."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                HeroCardIcon(systemImage: "gauge.with.needle", tint: .orange)
            }
        }
    }

    // MARK: - Gerenciador de Desempenho (claro)

    private var manager: some View {
        ManagerSurface {
            VStack(spacing: 0) {
                CleanTopBar(
                    leftIcon: "chevron.left",
                    leftTitle: t("Voltar", "Back"),
                    title: t("Gerenciador de Desempenho", "Performance Manager"),
                    leftAction: { withAnimation(.easeInOut(duration: 0.2)) { screen = .hero } }
                )

                Divider()

                HStack(spacing: 0) {
                    managerSidebar
                        .frame(width: 250)
                    Divider()
                    managerDetail
                        .frame(maxWidth: .infinity)
                }

                ManagerBottomBar(
                    summary: managerSummary,
                    actionTitle: t("Executar", "Run"),
                    actionDisabled: category != .tasks || selectedTasks.isEmpty || maintenance.isRunning,
                    action: { maintenance.run(taskIDs: selectedTasks) }
                )
            }
        }
    }

    private var managerSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ManagerCategory.allCases) { value in
                ManagerSidebarRow(
                    icon: categoryIcon(value),
                    iconTint: .orange,
                    title: categoryTitle(value),
                    badge: categoryBadge(value),
                    isSelected: category == value,
                    action: { category = value }
                )
                .padding(.horizontal, 6)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var managerDetail: some View {
        switch category {
        case .tasks: tasksDetail
        case .startup: startupDetail
        case .processes: processesDetail
        }
    }

    private var tasksDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader(
                title: t("Tarefas de Manutenção", "Maintenance Tasks"),
                subtitle: t("O macOS se cuida bem, mas sempre dá para ir além. Selecione e execute as tarefas recomendadas.",
                            "macOS does a pretty good job of self-care, but there's always room for more.")
            )
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(maintenance.tasks) { task in
                        HStack(spacing: 10) {
                            Toggle("", isOn: taskBinding(task.id))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            Image(systemName: task.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 8).fill(.orange))
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(settings.text(ptBR: task.titlePT, en: task.titleEN))
                                        .font(.system(size: 12.5, weight: .semibold))
                                    if task.needsAdmin {
                                        Text(t("senha", "password"))
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(Capsule().fill(Color.black.opacity(0.06)))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(settings.text(ptBR: task.detailPT, en: task.detailEN))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                    }

                    if maintenance.isRunning {
                        ProgressView(t("Executando…", "Running…")).controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
    }

    private var startupDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader(
                title: t("Itens de Inicialização", "Login Items"),
                subtitle: t("Agentes e daemons carregados no login. Itens do usuário podem ser removidos.",
                            "Agents and daemons loaded at login. User items can be removed.")
            )
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(service.items) { item in
                        HStack(spacing: 10) {
                            Image(systemName: domainIcon(item.domain))
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.label)
                                    .font(.system(size: 12, weight: .medium))
                                if let program = item.programPath {
                                    Text(program)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                            Spacer()
                            Text(domainLabel(item.domain))
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.orange.opacity(0.14)))
                                .foregroundStyle(.orange)
                            Button {
                                FileSweeper.revealInFinder(item.url)
                            } label: {
                                Image(systemName: "magnifyingglass").font(.system(size: 10))
                            }
                            .buttonStyle(.borderless)
                            if item.isRemovable {
                                Button(role: .destructive) {
                                    itemPendingRemoval = item
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 10))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
    }

    private var processesDetail: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader(
                title: t("Processos Pesados", "Heavy Processes"),
                subtitle: t("Os maiores consumidores de CPU e memória. Para encerrar, use o Monitor de Atividade.",
                            "Top CPU and memory consumers. Use Activity Monitor to quit them.")
            )
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(service.processes) { process in
                        HStack {
                            Text(process.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "CPU %.1f%%", process.cpuPercent))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(process.cpuPercent > 50 ? .orange : .secondary)
                                .frame(width: 86, alignment: .trailing)
                            Text(String(format: "RAM %.1f%%", process.memoryPercent))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 86, alignment: .trailing)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
    }

    private func detailHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 16, weight: .bold))
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func openManager(_ value: ManagerCategory) {
        category = value
        withAnimation(.easeInOut(duration: 0.2)) { screen = .manager }
    }

    private var managerSummary: String {
        switch category {
        case .tasks:
            return t("\(selectedTasks.count) Tarefas Selecionadas", "\(selectedTasks.count) Tasks Selected")
        case .startup:
            return t("\(service.items.count) itens de inicialização", "\(service.items.count) login items")
        case .processes:
            return t("\(service.processes.count) processos", "\(service.processes.count) processes")
        }
    }

    private func categoryTitle(_ value: ManagerCategory) -> String {
        switch value {
        case .tasks: return t("Tarefas de Manutenção", "Maintenance Tasks")
        case .startup: return t("Inicialização", "Login Items")
        case .processes: return t("Processos", "Processes")
        }
    }

    private func categoryIcon(_ value: ManagerCategory) -> String {
        switch value {
        case .tasks: return "wrench.and.screwdriver.fill"
        case .startup: return "power"
        case .processes: return "cpu"
        }
    }

    private func categoryBadge(_ value: ManagerCategory) -> String {
        switch value {
        case .tasks: return "\(maintenance.tasks.count)"
        case .startup: return "\(service.items.count)"
        case .processes: return "\(service.processes.count)"
        }
    }

    private func taskBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedTasks.contains(id) },
            set: { isOn in
                if isOn { selectedTasks.insert(id) } else { selectedTasks.remove(id) }
            }
        )
    }

    private func domainIcon(_ domain: StartupItem.Domain) -> String {
        switch domain {
        case .userAgent: return "person"
        case .globalAgent: return "person.2"
        case .globalDaemon: return "gearshape.2"
        }
    }

    private func domainLabel(_ domain: StartupItem.Domain) -> String {
        switch domain {
        case .userAgent: return t("Usuário", "User")
        case .globalAgent: return t("Global", "Global")
        case .globalDaemon: return "Daemon"
        }
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
