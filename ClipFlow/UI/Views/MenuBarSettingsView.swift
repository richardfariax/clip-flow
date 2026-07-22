import SwiftUI

struct MenuBarSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("Painel flutuante", "Floating dashboard"))
                            .font(.headline)
                        Text(t(
                            "Clique em qualquer métrica para abrir. Use o modo rápido ou detalhado.",
                            "Click any metric to open it. Choose quick or detailed mode."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(t("Visualizar painel", "Preview dashboard")) {
                        NotificationCenter.default.post(name: .showMetricsPopover, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Section {
                ForEach(MenuBarMetric.allCases) { metric in
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: metric))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color(for: metric))
                            .frame(width: 26)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title(for: metric)).font(.headline)
                            Text(example(for: metric))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Picker("", selection: binding(for: metric)) {
                            ForEach(MenuBarMetricStyle.allCases) { style in
                                Text(styleTitle(style)).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            } footer: {
                Label(
                    t(
                        "O ClipFlow preenche automaticamente o lado direito e usa a área livre à esquerda do notch apenas para as métricas que não couberem.",
                        "ClipFlow automatically fills the right side and uses the free area left of the notch only for metrics that do not fit."
                    ),
                    systemImage: "info.circle"
                )
            }
        }
        .clipFlowSettingsFormStyle()
    }

    private func binding(for metric: MenuBarMetric) -> Binding<MenuBarMetricStyle> {
        Binding(
            get: { settings.menuBarStyle(for: metric) },
            set: { settings.setMenuBarStyle($0, for: metric) }
        )
    }

    private func title(for metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: t("Memória", "Memory")
        case .temperature: t("Temperatura", "Temperature")
        case .fans: t("Ventoinhas", "Fans")
        case .storage: t("Armazenamento", "Storage")
        case .network: t("Rede", "Network")
        case .power: t("Energia", "Power")
        }
    }

    private func symbol(for metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu: "cpu"
        case .gpu: "square.3.layers.3d"
        case .memory: "memorychip"
        case .temperature: "thermometer.medium"
        case .fans: "fan"
        case .storage: "internaldrive"
        case .network: "network"
        case .power: "bolt.fill"
        }
    }

    private func color(for metric: MenuBarMetric) -> Color {
        switch metric {
        case .cpu: .blue
        case .gpu: .cyan
        case .memory: .purple
        case .temperature: .orange
        case .fans: .mint
        case .storage: .indigo
        case .network: .teal
        case .power: .yellow
        }
    }

    private func example(for metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu: "CPU 24%"
        case .gpu: "GPU 12%"
        case .memory: "RAM 68%"
        case .temperature: "58°C"
        case .fans: "2.340 RPM"
        case .storage: "SSD 41%"
        case .network: "↓1,2 MB/s ↑240 KB/s"
        case .power: "⚡︎84% 9,4W"
        }
    }

    private func styleTitle(_ style: MenuBarMetricStyle) -> String {
        switch style {
        case .hidden: t("Oculto", "Hidden")
        case .text: t("Número", "Number")
        case .graph: t("Gráfico", "Graph")
        case .textAndGraph: t("Número + gráfico", "Number + graph")
        }
    }

    private func t(_ pt: String, _ en: String) -> String { settings.text(ptBR: pt, en: en) }
}
