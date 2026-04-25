import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionsManager: PermissionsManager

    let launchManager: LaunchAtLoginManager
    let onRebindHotkey: () -> Void

    @State private var ignoredAppsText: String = ""
    @State private var launchAtLoginError: String?
    @State private var selectedHotkeyPresetID: String = HotkeyPreset.customID

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    glassSection(title: "Geral", subtitle: "Comportamento e aparência do app") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("Limite do Histórico", selection: $settings.historyLimit) {
                                Text("100").tag(100)
                                Text("500").tag(500)
                                Text("1000").tag(1000)
                            }

                            Picker("Aparência", selection: $settings.appearance) {
                                ForEach(AppAppearance.allCases) { appearance in
                                    Text(appearance.title).tag(appearance)
                                }
                            }

                            Toggle("Pausar monitoramento", isOn: $settings.pauseMonitoring)

                            Toggle("Criptografia local (AES-GCM)", isOn: $settings.enableEncryption)
                        }
                    }

                    glassSection(title: "Inicialização", subtitle: "Abertura automática com o macOS") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Iniciar com o macOS", isOn: Binding(
                                get: { settings.launchAtLogin },
                                set: { newValue in
                                    do {
                                        try launchManager.setEnabled(newValue)
                                        settings.launchAtLogin = launchManager.isEnabled
                                        launchAtLoginError = nil
                                    } catch {
                                        settings.launchAtLogin = launchManager.isEnabled
                                        launchAtLoginError = error.localizedDescription
                                    }
                                }
                            ))

                            if let launchAtLoginError {
                                Text(launchAtLoginError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    glassSection(title: "Atalho Global", subtitle: "Abertura rápida do painel") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Atalho atual")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(settings.hotkeyDisplay)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }

                                Spacer()

                                Button("Reaplicar Atalho") {
                                    onRebindHotkey()
                                }
                            }

                            Picker("Preset de Atalho", selection: $selectedHotkeyPresetID) {
                                ForEach(HotkeyPreset.all) { preset in
                                    Text(preset.title).tag(preset.id)
                                }
                                Text("Personalizado").tag(HotkeyPreset.customID)
                            }
                            .onChange(of: selectedHotkeyPresetID, initial: false) { _, newValue in
                                guard let selectedPreset = HotkeyPreset.all.first(where: { $0.id == newValue }) else {
                                    return
                                }

                                settings.hotkeyCode = selectedPreset.keyCode
                                settings.hotkeyModifiers = selectedPreset.modifiers
                                onRebindHotkey()
                            }

                            Text("Se o valor atual não bater com um preset, ele aparece como Personalizado.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    glassSection(title: "Apps Ignorados", subtitle: "Proteção para apps sensíveis") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Um bundle id por linha. Ex.: com.1password.1password")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $ignoredAppsText)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button("Salvar Lista") {
                                settings.ignoredBundleIDs = ignoredAppsText
                                    .split(separator: "\n")
                                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                ignoredAppsText = settings.ignoredBundleIDs.joined(separator: "\n")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    glassSection(title: "Permissões", subtitle: "Necessárias para hotkeys e colagem automática") {
                        PermissionsView(permissionsManager: permissionsManager)
                            .frame(height: 280)
                    }
                }
                .padding(18)
            }
        }
        .frame(width: 620, height: 820)
        .onAppear {
            ignoredAppsText = settings.ignoredBundleIDs.joined(separator: "\n")
            settings.launchAtLogin = launchManager.isEnabled
            permissionsManager.refresh()
            syncHotkeyPresetState()
        }
        .onChange(of: settings.hotkeyCode, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
        .onChange(of: settings.hotkeyModifiers, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.02),
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            BrandLogoView(size: 32, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text("ClipFlow")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                Text("Preferências")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private func glassSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.0)
                )
        )
    }

    private func syncHotkeyPresetState() {
        selectedHotkeyPresetID = HotkeyPreset
            .matching(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)?
            .id ?? HotkeyPreset.customID
    }
}
