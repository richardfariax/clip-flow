import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @State private var refreshTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ClipFlow precisa de Accessibility para colar automaticamente e Input Monitoring para capturar atalhos globais com máxima confiabilidade.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if isRunningFromDerivedData {
                Text("Você está rodando via Xcode/DerivedData. Para permissões estáveis de Accessibility/Input Monitoring, use o app instalado em /Applications (.dmg).")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

            Text("Depois de conceder, volte ao app para atualizar o status.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Reverificar Agora") {
                permissionsManager.refresh()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(2)
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(granted ? "Concedida" : "Não concedida")
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }

            Spacer()

            Button("Solicitar") {
                requestAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(granted)

            Button("Abrir Ajustes") {
                openAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1.0)
                )
        )
    }

    private var isRunningFromDerivedData: Bool {
        Bundle.main.bundlePath.contains("DerivedData")
    }
}
