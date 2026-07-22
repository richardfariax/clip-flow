import AppKit
import SwiftUI

/// Módulos do centro de limpeza, inspirados no CleanMyMac.
enum CleanModule: String, CaseIterable, Identifiable {
    case smartScan
    case junk
    case speedup
    case apps
    case duplicates
    case largeFiles
    case diskMap
    case protection

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .smartScan: return "sparkles"
        case .junk: return "trash.circle.fill"
        case .speedup: return "bolt.fill"
        case .apps: return "square.grid.2x2.fill"
        case .duplicates: return "folder.fill.badge.questionmark"
        case .largeFiles: return "externaldrive.fill"
        case .diskMap: return "circle.hexagongrid.fill"
        case .protection: return "shield.lefthalf.filled"
        }
    }

    var tint: Color {
        switch self {
        case .smartScan: return .purple
        case .junk: return .green
        case .speedup: return .orange
        case .apps: return .blue
        case .duplicates: return .teal
        case .largeFiles: return .indigo
        case .diskMap: return Color(red: 0.72, green: 0.4, blue: 1.0)
        case .protection: return .mint
        }
    }

    /// Gradiente imersivo de fundo, no estilo CleanMyMac.
    var backgroundGradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .smartScan:
            colors = [Color(red: 0.16, green: 0.09, blue: 0.30), Color(red: 0.05, green: 0.03, blue: 0.12)]
        case .junk:
            colors = [Color(red: 0.05, green: 0.30, blue: 0.14), Color(red: 0.01, green: 0.10, blue: 0.05)]
        case .speedup:
            colors = [Color(red: 0.45, green: 0.22, blue: 0.06), Color(red: 0.16, green: 0.07, blue: 0.02)]
        case .apps:
            colors = [Color(red: 0.12, green: 0.16, blue: 0.50), Color(red: 0.03, green: 0.05, blue: 0.20)]
        case .duplicates:
            colors = [Color(red: 0.05, green: 0.30, blue: 0.30), Color(red: 0.01, green: 0.12, blue: 0.13)]
        case .largeFiles:
            colors = [Color(red: 0.16, green: 0.15, blue: 0.45), Color(red: 0.05, green: 0.04, blue: 0.17)]
        case .diskMap:
            colors = [Color(red: 0.26, green: 0.11, blue: 0.48), Color(red: 0.08, green: 0.02, blue: 0.19)]
        case .protection:
            colors = [Color(red: 0.03, green: 0.27, blue: 0.22), Color(red: 0.01, green: 0.10, blue: 0.09)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    func title(_ t: (String, String) -> String) -> String {
        switch self {
        case .smartScan: return t("Análise Inteligente", "Smart Scan")
        case .junk: return t("Limpeza", "Cleanup")
        case .speedup: return t("Desempenho", "Performance")
        case .apps: return t("Aplicativos", "Applications")
        case .duplicates: return t("Meu Acúmulo", "My Clutter")
        case .largeFiles: return t("Grandes e Antigos", "Large & Old")
        case .diskMap: return t("Lupa de Espaço", "Space Lens")
        case .protection: return t("Proteção", "Protection")
        }
    }
}

struct CleanCenterView: View {
    @ObservedObject var settings: AppSettings

    @StateObject private var junkService = JunkScanService()
    @StateObject private var startupService = StartupItemsService()
    @StateObject private var maintenanceService = MaintenanceService()
    @StateObject private var appsService = AppInventoryService()
    @StateObject private var duplicatesService = DuplicateFinderService()
    @StateObject private var similarImagesService = SimilarImagesService()
    @StateObject private var largeFilesService = LargeOldFilesService()
    @StateObject private var diskMapService = DiskMapService()
    @StateObject private var protectionService = ProtectionService()

    @State private var selection: CleanModule = .smartScan

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(selection.backgroundGradient.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .frame(minWidth: 1080, minHeight: 700)
    }

    // MARK: - Sidebar (apenas ícones, como no CleanMyMac)

    private var sidebar: some View {
        VStack(spacing: 10) {
            ForEach(CleanModule.allCases) { module in
                sidebarIcon(module)
            }
            Spacer()
        }
        .padding(.top, 46)
        .frame(width: 52)
        .background(Color.black.opacity(0.22))
    }

    private func sidebarIcon(_ module: CleanModule) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                selection = module
            }
        } label: {
            Image(systemName: module.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selection == module ? Color.white : Color.white.opacity(0.5))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(selection == module ? .white.opacity(0.22) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(module.title(t))
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .smartScan:
            SmartScanView(
                settings: settings,
                junkService: junkService,
                protectionService: protectionService,
                startupService: startupService,
                onOpenModule: { selection = $0 }
            )
        case .junk:
            JunkCleanView(settings: settings, service: junkService)
        case .speedup:
            SpeedupView(settings: settings, service: startupService, maintenance: maintenanceService)
        case .apps:
            AppsManagerView(settings: settings, service: appsService)
        case .duplicates:
            DuplicatesView(settings: settings, service: duplicatesService, similarService: similarImagesService)
        case .largeFiles:
            LargeFilesView(settings: settings, service: largeFilesService)
        case .diskMap:
            DiskMapView(settings: settings, service: diskMapService)
        case .protection:
            ProtectionView(settings: settings, service: protectionService)
        }
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}

// MARK: - Barra superior dos módulos

/// Barra do topo: ação à esquerda ("Recomeçar"/"Voltar"), título centralizado.
struct CleanTopBar<Trailing: View>: View {
    let leftIcon: String
    let leftTitle: String
    let title: String
    let leftAction: () -> Void
    @ViewBuilder var trailing: Trailing

    init(
        leftIcon: String,
        leftTitle: String,
        title: String,
        leftAction: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.leftIcon = leftIcon
        self.leftTitle = leftTitle
        self.title = title
        self.leftAction = leftAction
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))
            HStack {
                Button(action: leftAction) {
                    Label(leftTitle, systemImage: leftIcon)
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary.opacity(0.75))
                Spacer()
                trailing
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }
}

// MARK: - Componentes da tela hero (fundo colorido)

/// Headline central grande + botão-pílula, como "There are 80 GB of junk files…".
struct HeroHeadline: View {
    let text: String
    let pillTitle: String?
    let pillAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let pillTitle, let pillAction {
                Button(pillTitle, action: pillAction)
                    .buttonStyle(CleanGlassButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 8)
    }
}

/// Card da tela hero com ações "Revisar"/"Limpar" no rodapé direito.
struct HeroCard<Content: View>: View {
    var minHeight: CGFloat = 150
    var emphasized: Bool = false
    let reviewTitle: String
    var cleanTitle: String? = nil
    let onReview: () -> Void
    var onClean: (() -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
            Spacer(minLength: 6)
            HStack(spacing: 8) {
                Spacer()
                Button(reviewTitle, action: onReview)
                    .buttonStyle(CleanGlassButtonStyle())
                if let cleanTitle, let onClean {
                    Button(cleanTitle, action: onClean)
                        .buttonStyle(CleanWhiteButtonStyle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white.opacity(emphasized ? 0.16 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

/// Ícone redondo translúcido usado no canto dos cards hero.
struct HeroCardIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [tint.opacity(0.9), tint.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
    }
}

// MARK: - Superfície clara de "Manager" (como o Cleanup Manager)

/// Contêiner claro dos gerenciadores: fundo branco, cantos arredondados,
/// esquema claro forçado — contraste com o fundo colorido do módulo.
struct ManagerSurface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(\.colorScheme, .light)
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(10)
            .transition(.opacity)
    }
}

/// Barra inferior clara: resumo centralizado + CTA rosa à direita.
struct ManagerBottomBar: View {
    let summary: String
    let actionTitle: String
    let actionDisabled: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Text(summary)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(CleanCTAButtonStyle())
                    .disabled(actionDisabled)
                    .opacity(actionDisabled ? 0.35 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.white)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Linha de categoria da sidebar do manager (destaque lavanda quando ativa).
struct ManagerSidebarRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    let badge: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(iconTint))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Text(badge)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(isSelected ? Color(red: 0.56, green: 0.35, blue: 0.97) : Color.black.opacity(0.06))
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(red: 0.90, green: 0.86, blue: 0.99) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Estilos de botão

/// CTA rosa, como o "Clean Up" do CleanMyMac.
struct CleanCTAButtonStyle: ButtonStyle {
    var tint: Color = Color(red: 0.91, green: 0.15, blue: 0.60)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.7 : 1))
            )
            .shadow(color: tint.opacity(0.35), radius: 8, y: 2)
    }
}

/// Botão translúcido de vidro (como "Review").
struct CleanGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.32 : 0.18))
            )
    }
}

/// Botão branco sólido (como o "Clean" dos cards hero).
struct CleanWhiteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(configuration.isPressed ? 0.75 : 0.95))
            )
    }
}

/// Cartão de vidro genérico sobre o gradiente (usos diversos).
struct CleanCard<Content: View>: View {
    var prominent: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(prominent ? 0.14 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                    )
            )
    }
}

/// Barra inferior escura (usada fora dos managers claros, ex.: Lupa de Espaço).
struct CleanBottomBar: View {
    let summary: String
    let actionTitle: String
    let actionDisabled: Bool
    let action: () -> Void

    var body: some View {
        ZStack {
            Text(summary)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            HStack {
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(CleanCTAButtonStyle())
                    .disabled(actionDisabled)
                    .opacity(actionDisabled ? 0.35 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.black.opacity(0.35))
    }
}
