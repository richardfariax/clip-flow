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
            VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image("ClipFlowLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ClipFlow")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Preferências")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    GroupBox("Geral") {
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
                        .padding(.top, 8)
                    }

                    GroupBox("Inicialização") {
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
                        .padding(.top, 8)
                    }

                    GroupBox("Atalho Global") {
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
                        .padding(.top, 8)
                    }

                    GroupBox("Apps Ignorados") {
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
                        .padding(.top, 8)
                    }

                    GroupBox("Permissões") {
                        PermissionsView(permissionsManager: permissionsManager)
                            .frame(height: 280)
                    }
                }
                .padding(22)
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

    private func syncHotkeyPresetState() {
        selectedHotkeyPresetID = HotkeyPreset
            .matching(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)?
            .id ?? HotkeyPreset.customID
    }
}
