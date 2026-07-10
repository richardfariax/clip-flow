import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var settings: AppSettings
    @State private var refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t(
                "ClipFlow precisa de Accessibility para colar automaticamente e Input Monitoring para capturar atalhos globais com máxima confiabilidade.",
                "ClipFlow needs Accessibility to paste automatically and Input Monitoring for more reliable global hotkeys."
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if isRunningFromDerivedData {
                Text(t(
                    "Você está rodando via Xcode/DerivedData. Permissões (incluindo Gravação de Tela) valem só para este build — use o app em /Applications (.dmg) para permissões estáveis.",
                    "You are running from Xcode/DerivedData. Permissions (including Screen Recording) apply only to this build — use the app in /Applications (.dmg) for stable permissions."
                ))
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.bottom, 2)
            }

            permissionRow(
                title: "Accessibility",
                granted: permissionsManager.isAccessibilityGranted,
                requestAction: permissionsManager.requestAccessibility,
                openAction: permissionsManager.openAccessibilitySettings
            )

            permissionRow(
                title: "Input Monitoring",
                granted: permissionsManager.isInputMonitoringGranted,
                requestAction: permissionsManager.requestInputMonitoring,
                openAction: permissionsManager.openInputMonitoringSettings
            )

            permissionRow(
                title: t("Gravação de Tela", "Screen Recording"),
                granted: permissionsManager.isScreenCaptureGranted,
                requestAction: permissionsManager.requestScreenCapture,
                openAction: permissionsManager.openScreenCaptureSettings
            )

            Text(t(
                "Depois de conceder, volte ao app para atualizar o status. Para Gravação de Tela, pode ser necessário fechar e abrir o ClipFlow novamente.",
                "After granting, return to the app to refresh status. For Screen Recording, you may need to quit and reopen ClipFlow."
            ))
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
        .onAppear {
            permissionsManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissionsManager.refresh()
        }
        .onReceive(refreshTimer) { _ in
            permissionsManager.refresh()
        }
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        requestAction: @escaping () -> Void,
        openAction: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(granted ? t("Concedida", "Granted") : t("Não concedida", "Not granted"))
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }

            Spacer()

            Button(t("Solicitar", "Request")) {
                requestAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(granted)

            Button {
                permissionsManager.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(t("Reverificar status", "Refresh status"))

            Button(t("Abrir Ajustes", "Open Settings")) {
                openAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1.0)
                )
        )
    }

    private var isRunningFromDerivedData: Bool {
        Bundle.main.bundlePath.contains("DerivedData")
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }
}
