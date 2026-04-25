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

                    generalSection

                    glassSection(
                        title: t("Atalho Global", "Global Hotkey"),
                        subtitle: t("Abertura rápida do painel", "Quick panel access"),
                        fillsWidth: true
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("Atalho atual", "Current hotkey"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(settings.hotkeyDisplay)
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                }

                                Spacer()

                                Button(t("Reaplicar Atalho", "Reapply Hotkey")) {
                                    onRebindHotkey()
                                }
                            }

                            Picker(t("Preset de Atalho", "Hotkey Preset"), selection: $selectedHotkeyPresetID) {
                                ForEach(HotkeyPreset.all) { preset in
                                    Text(preset.title(for: settings.language)).tag(preset.id)
                                }
                                Text(t("Personalizado", "Custom")).tag(HotkeyPreset.customID)
                            }
                            .onChange(of: selectedHotkeyPresetID, initial: false) { _, newValue in
                                guard let selectedPreset = HotkeyPreset.all.first(where: { $0.id == newValue }) else {
                                    return
                                }

                                settings.hotkeyCode = selectedPreset.keyCode
                                settings.hotkeyModifiers = selectedPreset.modifiers
                                onRebindHotkey()
                            }

                            Text(t(
                                "Se o valor atual não bater com um preset, ele aparece como Personalizado.",
                                "If the current value does not match a preset, it appears as Custom."
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    glassSection(
                        title: t("Apps Ignorados", "Ignored Apps"),
                        subtitle: t("Proteção para apps sensíveis", "Protection for sensitive apps"),
                        fillsWidth: true
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t(
                                "Um bundle id por linha. Ex.: com.1password.1password",
                                "One bundle id per line. Ex: com.1password.1password"
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            TextEditor(text: $ignoredAppsText)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                                .frame(height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Button(t("Salvar Lista", "Save List")) {
                                settings.ignoredBundleIDs = ignoredAppsText
                                    .split(separator: "\n")
                                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }
                                ignoredAppsText = settings.ignoredBundleIDs.joined(separator: "\n")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    glassSection(
                        title: t("Permissões", "Permissions"),
                        subtitle: t("Necessárias para hotkeys e colagem automática", "Required for hotkeys and automatic paste"),
                        fillsWidth: true
                    ) {
                        PermissionsView(permissionsManager: permissionsManager, settings: settings)
                            .frame(height: 280)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
        .frame(minWidth: 760, minHeight: 820)
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
                Text(t("Preferências", "Preferences"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private var generalSection: some View {
        glassSection(
            title: t("Geral", "General"),
            subtitle: t("Configurações principais do app", "Main app behavior settings"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                settingsRow(title: t("Limite do Histórico", "History Limit")) {
                    Picker("", selection: $settings.historyLimit) {
                        Text("100").tag(100)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                settingsRow(title: t("Idioma", "Language")) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }

                settingsRow(title: t("Aparência", "Appearance")) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title(for: settings.language)).tag(appearance)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 170)
                }

                settingsRow(title: t("Iniciar com o macOS", "Launch at Login")) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                }

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                Toggle(t("Pausar monitoramento", "Pause monitoring"), isOn: $settings.pauseMonitoring)

                Toggle(t("Criptografia local (AES-GCM)", "Local encryption (AES-GCM)"), isOn: $settings.enableEncryption)
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
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
        )
    }

    private func glassSection<Content: View>(
        title: String,
        subtitle: String,
        fillsWidth: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
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

    private func settingsRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, alignment: .leading)

            content()
        }
    }

    private func syncHotkeyPresetState() {
        selectedHotkeyPresetID = HotkeyPreset
            .matching(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)?
            .id ?? HotkeyPreset.customID
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }
}
