import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionsManager: PermissionsManager

    let launchManager: LaunchAtLoginManager
    let onRebindHotkey: () -> Void

    @State private var ignoredAppsText: String = ""
    @State private var launchAtLoginError: String?
    @State private var selectedHotkeyPresetID: String = HotkeyPreset.customID

    private let labelColumnWidth: CGFloat = 220
    private let defaultControlWidth: CGFloat = 250

    private let creditsURL = URL(string: "https://www.linkedin.com/in/richardfariasss/")!

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    generalSection
                    hotkeySection
                    ignoredAppsSection
                    permissionsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
        .frame(minWidth: 760, minHeight: 860)
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

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(t("Desenvolvido por", "Built by"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Link("Richard Farias", destination: creditsURL)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.blue.opacity(0.95))
            }
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 2)
    }

    private var generalSection: some View {
        glassSection(
            title: t("Geral", "General"),
            subtitle: t("Configurações principais do app", "Main app behavior settings"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 12) {
                alignedConfigRow(title: t("Limite do Histórico", "History Limit")) {
                    Picker("", selection: $settings.historyLimit) {
                        Text("100").tag(100)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Idioma", "Language")) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Aparência", "Appearance")) {
                    Picker("", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title(for: settings.language)).tag(appearance)
                        }
                    }
                    .labelsHidden()
                }

                alignedConfigRow(title: t("Iniciar com o macOS", "Launch at Login")) {
                    Toggle("", isOn: launchAtLoginBinding)
                        .labelsHidden()
                }

                if let launchAtLoginError {
                    alignedConfigNote(launchAtLoginError, color: .red)
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                alignedConfigRow(title: t("Pausar monitoramento", "Pause monitoring")) {
                    Toggle("", isOn: $settings.pauseMonitoring)
                        .labelsHidden()
                }

                alignedConfigRow(title: t("Criptografia local (AES-GCM)", "Local encryption (AES-GCM)")) {
                    Toggle("", isOn: $settings.enableEncryption)
                        .labelsHidden()
                }
            }
        }
    }

    private var hotkeySection: some View {
        glassSection(
            title: t("Atalho Global", "Global Hotkey"),
            subtitle: t("Abertura rápida do painel", "Quick panel access"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 12) {
                alignedConfigRow(title: t("Atalho atual", "Current hotkey"), controlWidth: 320) {
                    Text(settings.hotkeyDisplay)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                alignedConfigRow(title: t("Preset de Atalho", "Hotkey Preset"), controlWidth: 320) {
                    Picker("", selection: $selectedHotkeyPresetID) {
                        ForEach(HotkeyPreset.all) { preset in
                            Text(preset.title(for: settings.language)).tag(preset.id)
                        }
                        Text(t("Personalizado", "Custom")).tag(HotkeyPreset.customID)
                    }
                    .labelsHidden()
                }
                .onChange(of: selectedHotkeyPresetID, initial: false) { _, newValue in
                    guard let selectedPreset = HotkeyPreset.all.first(where: { $0.id == newValue }) else {
                        return
                    }

                    settings.hotkeyCode = selectedPreset.keyCode
                    settings.hotkeyModifiers = selectedPreset.modifiers
                    onRebindHotkey()
                }

                alignedConfigRow(title: t("Reaplicar atalho", "Reapply hotkey"), controlWidth: 320) {
                    Button(t("Reaplicar Atalho", "Reapply Hotkey")) {
                        onRebindHotkey()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                alignedConfigNote(
                    t(
                        "Se o valor atual não bater com um preset, ele aparece como Personalizado.",
                        "If the current value does not match a preset, it appears as Custom."
                    )
                )
            }
        }
    }

    private var ignoredAppsSection: some View {
        glassSection(
            title: t("Apps Ignorados", "Ignored Apps"),
            subtitle: t("Proteção para apps sensíveis", "Protection for sensitive apps"),
            fillsWidth: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                alignedConfigRow(
                    title: t("Bundle IDs ignorados", "Ignored bundle IDs"),
                    controlWidth: 430
                ) {
                    TextEditor(text: $ignoredAppsText)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .frame(height: 132)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                alignedConfigNote(
                    t(
                        "Um bundle id por linha. Ex.: com.1password.1password",
                        "One bundle id per line. Ex: com.1password.1password"
                    )
                )

                alignedConfigRow(title: t("Salvar alterações", "Save changes"), controlWidth: 430) {
                    Button(t("Salvar Lista", "Save List")) {
                        settings.ignoredBundleIDs = ignoredAppsText
                            .split(separator: "\n")
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        ignoredAppsText = settings.ignoredBundleIDs.joined(separator: "\n")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var permissionsSection: some View {
        glassSection(
            title: t("Permissões", "Permissions"),
            subtitle: t("Necessárias para hotkeys e colagem automática", "Required for hotkeys and automatic paste"),
            fillsWidth: true
        ) {
            PermissionsView(permissionsManager: permissionsManager, settings: settings)
                .frame(height: 280)
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

    private func alignedConfigRow<Control: View>(
        title: String,
        controlWidth: CGFloat? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .frame(width: labelColumnWidth, alignment: .leading)

            Spacer(minLength: 0)

            control()
                .frame(width: controlWidth ?? defaultControlWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func alignedConfigNote(_ text: String, color: Color = .secondary) -> some View {
        HStack(spacing: 12) {
            Spacer()
                .frame(width: labelColumnWidth)

            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
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
