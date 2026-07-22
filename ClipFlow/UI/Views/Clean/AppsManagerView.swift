import AppKit
import SwiftUI

/// Aplicativos fiel ao CleanMyMac: hero azul com Scan e gerenciador claro
/// com desinstalação + sobras.
struct AppsManagerView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var service: AppInventoryService

    private enum Screen {
        case hero
        case manager
    }

    @State private var screen: Screen = .hero
    @State private var search = ""
    @State private var selectedLeftovers: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            switch screen {
            case .hero: hero
            case .manager: manager
            }
        }
        .sheet(isPresented: Binding(
            get: { service.leftovers != nil },
            set: { if !$0 { service.dismissLeftovers() } }
        )) {
            if let leftovers = service.leftovers {
                leftoversSheet(leftovers)
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 0) {
            CleanTopBar(
                leftIcon: "arrow.counterclockwise",
                leftTitle: t("Recomeçar", "Start Over"),
                title: t("Aplicativos", "Applications"),
                leftAction: {}
            )

            Spacer()

            HStack(spacing: 40) {
                appHexIcon

                VStack(alignment: .leading, spacing: 14) {
                    Text(t("Aplicativos", "Applications"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                    Text(t("Assuma o controle dos seus aplicativos. Desinstale,\nveja tamanhos e remova sobras antigas.",
                           "Take control of your applications. Uninstall,\nsee sizes or remove old application leftovers."))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 10) {
                        featureRow(icon: "xmark.circle.fill", text: t("Desinstalador de Apps", "App Uninstaller"))
                        featureRow(icon: "internaldrive.fill", text: t("Tamanho real de cada app", "True size of every app"))
                        featureRow(icon: "doc.badge.gearshape.fill", text: t("Sobras de Arquivos", "File Leftovers"))
                    }
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity)

            Spacer()

            scanButton
                .padding(.bottom, 34)
        }
        .onAppear {
            if !service.apps.isEmpty { screen = .manager }
        }
    }

    private var appHexIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.25, green: 0.35, blue: 0.95), Color(red: 0.10, green: 0.14, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 170, height: 170)
                .shadow(color: .blue.opacity(0.5), radius: 26, y: 8)
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 62, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.12)))
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var scanButton: some View {
        Button {
            service.refresh()
            withAnimation(.easeInOut(duration: 0.2)) { screen = .manager }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.35, green: 0.75, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: .cyan.opacity(0.5), radius: 16, y: 4)
                Text(t("Analisar", "Scan"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manager (claro)

    private var manager: some View {
        ManagerSurface {
            VStack(spacing: 0) {
                CleanTopBar(
                    leftIcon: "chevron.left",
                    leftTitle: t("Voltar", "Back"),
                    title: t("Gerenciador de Aplicativos", "Applications Manager"),
                    leftAction: { withAnimation(.easeInOut(duration: 0.2)) { screen = .hero } }
                ) {
                    TextField(t("Buscar…", "Search…"), text: $search)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                Divider()

                if service.isLoading {
                    Spacer()
                    ProgressView(t("Calculando tamanhos…", "Calculating sizes…"))
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(filteredApps) { app in
                                appRow(app)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                }

                if let error = service.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.orange).padding(.bottom, 4)
                }

                ManagerBottomBar(
                    summary: "\(filteredApps.count) apps  |  " + CleanFormat.bytes(totalBytes),
                    actionTitle: t("Atualizar", "Refresh"),
                    actionDisabled: service.isLoading,
                    action: { service.refresh() }
                )
            }
        }
    }

    private var filteredApps: [InstalledApp] {
        guard !search.isEmpty else { return service.apps }
        return service.apps.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var totalBytes: UInt64 {
        filteredApps.reduce(0) { $0 + $1.bytes }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).font(.system(size: 12.5, weight: .semibold))
                HStack(spacing: 6) {
                    if let version = app.version { Text("v\(version)") }
                    if let bundleID = app.bundleIdentifier {
                        Text(bundleID).lineLimit(1).truncationMode(.middle)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(CleanFormat.bytes(app.bytes))
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.95))
            Button {
                FileSweeper.revealInFinder(app.url)
            } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 10))
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                selectedLeftovers = []
                service.findLeftovers(for: app)
            } label: {
                Text(t("Desinstalar", "Uninstall")).font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .disabled(isProtected(app))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 9).fill(Color.black.opacity(0.025)))
    }

    /// Evita que o usuário remova o próprio ClipFlow sem querer.
    private func isProtected(_ app: InstalledApp) -> Bool {
        app.bundleIdentifier?.lowercased().contains("clipflow") == true
    }

    // MARK: - Sheet de sobras

    private func leftoversSheet(_ leftovers: AppLeftovers) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(nsImage: leftovers.app.icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("Desinstalar ", "Uninstall ") + leftovers.app.name)
                        .font(.headline)
                    Text(t("O app e as sobras marcadas vão para a Lixeira.",
                           "The app and checked leftovers move to the Trash."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if leftovers.items.isEmpty {
                Text(t("Nenhuma sobra encontrada.", "No leftovers found."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(leftovers.items) { item in
                            HStack(spacing: 8) {
                                Toggle("", isOn: leftoverBinding(item.url))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.name).font(.caption.weight(.medium))
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
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)
            }

            HStack {
                Button(t("Cancelar", "Cancel")) {
                    service.dismissLeftovers()
                }
                Spacer()
                Button {
                    service.uninstall(app: leftovers.app, leftoverURLs: Array(selectedLeftovers))
                } label: {
                    if service.isUninstalling {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(t("Mover para a Lixeira", "Move to Trash"))
                    }
                }
                .buttonStyle(CleanCTAButtonStyle())
                .disabled(service.isUninstalling)
            }
        }
        .padding(20)
        .frame(width: 480)
        .environment(\.colorScheme, .light)
        .onAppear {
            selectedLeftovers = Set(leftovers.items.map(\.url))
        }
    }

    private func leftoverBinding(_ url: URL) -> Binding<Bool> {
        Binding(
            get: { selectedLeftovers.contains(url) },
            set: { isOn in
                if isOn { selectedLeftovers.insert(url) } else { selectedLeftovers.remove(url) }
            }
        )
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
