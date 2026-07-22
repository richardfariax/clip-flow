import SwiftUI

struct MenuBarSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
            .padding(14)
            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Toggle(isOn: $settings.useNotchLeftOverflow) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Overflow à esquerda do notch", "Overflow to the left of the notch"))
                        .font(.headline)
                    Text(t(
                        "Se o macOS ocultar as métricas por falta de espaço, o ClipFlow move o grupo para a área livre à esquerda do notch.",
                        "If macOS hides metrics because space is tight, ClipFlow moves the group into the free area left of the notch."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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
                    .frame(width: 160)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Label(
                t(
                    "Se faltar espaço à direita, o ClipFlow pode mover as métricas para a área livre à esquerda do notch.",
                    "When space runs out on the right, ClipFlow can move metrics into the free area left of the notch."
                ),
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
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
