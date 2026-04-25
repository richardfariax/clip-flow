import SwiftUI

struct PermissionsView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Permissões")
                .font(.title2.bold())

            Text("ClipVault precisa de Accessibility para colar automaticamente e Input Monitoring para capturar atalhos globais com máxima confiabilidade.")
                .font(.callout)
                .foregroundStyle(.secondary)

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

            Spacer()
        }
        .padding(24)
        .frame(width: 520, height: 300)
        .background(VisualEffectBlur(material: .underWindowBackground, blendingMode: .withinWindow))
        .onAppear {
            permissionsManager.refresh()
        }
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        requestAction: @escaping () -> Void,
        openAction: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(granted ? "Concedida" : "Não concedida")
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }

            Spacer()

            Button("Solicitar") {
                requestAction()
            }
            .buttonStyle(.borderedProminent)

            Button("Abrir Ajustes") {
                openAction()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
