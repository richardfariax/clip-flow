import AppKit
import SwiftUI

private enum SettingsPane: String, Identifiable, Hashable {
    case general
    case menuBar
    case hotkey
    case ignoredApps
    case dashboard
    case maintenance
    case voice
    case intelligence
    case permissions
    case about

    var id: String { rawValue }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .dashboard:
            return language.text(ptBR: "Central", en: "Command Center")
        case .menuBar:
            return language.text(ptBR: "Barra Superior", en: "Menu Bar")
        case .maintenance:
            return language.text(ptBR: "Manutenção", en: "Maintenance")
        case .general:
            return language.text(ptBR: "Geral", en: "General")
        case .voice:
            return language.text(ptBR: "Voz", en: "Voice")
        case .intelligence:
            return language.text(ptBR: "Inteligência", en: "Intelligence")
        case .hotkey:
            return language.text(ptBR: "Atalhos", en: "Shortcuts")
        case .ignoredApps:
            return language.text(ptBR: "Apps Ignorados", en: "Ignored Apps")
        case .permissions:
            return language.text(ptBR: "Permissões", en: "Permissions")
        case .about:
            return language.text(ptBR: "Sobre e Atualizações", en: "About & Updates")
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .menuBar: return "menubar.rectangle"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .general: return "gearshape.fill"
        case .voice: return "waveform"
        case .intelligence: return "sparkles"
        case .hotkey: return "keyboard"
        case .ignoredApps: return "hand.raised.slash.fill"
        case .permissions: return "lock.shield.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .dashboard: return .blue
        case .menuBar: return .cyan
        case .maintenance: return .green
        case .general: return .gray
        case .voice: return .pink
        case .intelligence: return .purple
        case .hotkey: return .blue
        case .ignoredApps: return .orange
        case .permissions: return .green
        case .about: return .cyan
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionsManager: PermissionsManager
    @ObservedObject var appUpdateService: AppUpdateService
    @ObservedObject var systemMetrics: SystemMetricsService

    let launchManager: LaunchAtLoginManager
    let onRebindHotkey: () -> Void

    @State private var selectedPane: SettingsPane = .general
    @State private var launchAtLoginError: String?
    @State private var selectedHotkeyPresetID: String = HotkeyPreset.customID

    @State private var availableApps: [InstalledApplication] = []
    @State private var appSearchText: String = ""
    @State private var selectedAvailableAppBundleID: String?
    @State private var selectedIgnoredAppBundleID: String?
    @State private var isLoadingAvailableApps = false
    @State private var isAddIgnoredAppSheetPresented = false
    @State private var isHoveringIgnoredAppsGrid = false
    @State private var isRecordingCustomHotkey = false
    @State private var hotkeyRecorderMonitor: AnyObject?
    @State private var hotkeyRecorderMessage: String?
    @StateObject private var generativeAnswers = GenerativeAnswerService()

    private let linkedInURL = URL(string: DeveloperProfileCatalog.linkedInURL)!
    private let githubURL = URL(string: DeveloperProfileCatalog.githubURL)!

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 196, ideal: 220, max: 260)
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(detailBackground)
        }
        .navigationSplitViewStyle(.balanced)
        .background(windowBackground)
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            settings.launchAtLogin = launchManager.isEnabled
            permissionsManager.refresh()
            syncHotkeyPresetState()
            loadAvailableAppsIfNeeded()
            generativeAnswers.refreshStatus(userName: settings.userName.isEmpty ? nil : settings.userName)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsPermissions)) { _ in
            selectedPane = .permissions
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsDashboard)) { _ in
            selectedPane = .dashboard
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsUpdates)) { _ in
            selectedPane = .about
        }
        .onChange(of: settings.hotkeyCode, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
        .onChange(of: settings.hotkeyModifiers, initial: false) { _, _ in
            syncHotkeyPresetState()
        }
        .onChange(of: selectedPane, initial: false) { _, _ in
            stopHotkeyRecording()
        }
        .sheet(isPresented: $isAddIgnoredAppSheetPresented) {
            addIgnoredAppsSheet
        }
        .onDisappear {
            stopHotkeyRecording()
        }
    }

    // MARK: - Chrome

    private var windowBackground: some View {
        VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
            .ignoresSafeArea()
    }

    private var detailBackground: some View {
        Color(nsColor: .windowBackgroundColor)
            .ignoresSafeArea()
    }

    private var sidebar: some View {
        List(selection: $selectedPane) {
            Section(t("Preferências", "Preferences")) {
                sidebarRows([.general, .menuBar, .hotkey, .ignoredApps])
            }

            Section(t("Recursos", "Features")) {
                sidebarRows([.dashboard, .maintenance, .voice, .intelligence])
            }

            Section(t("Sistema", "System")) {
                sidebarRows([.permissions])
            }

            Section {
                sidebarRows([.about])
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
    }

    @ViewBuilder
    private func sidebarRows(_ panes: [SettingsPane]) -> some View {
        ForEach(panes) { pane in
            HStack(spacing: 8) {
                Label {
                    Text(pane.title(for: settings.language))
                } icon: {
                    settingsIcon(symbol: pane.symbolName, tint: pane.tint)
                }

                if pane == .about, appUpdateService.hasUpdateAvailable {
                    Spacer(minLength: 0)
                    Circle()
                        .fill(Color.teal)
                        .frame(width: 7, height: 7)
                        .accessibilityLabel(t("Atualização disponível", "Update available"))
                }
            }
            .tag(pane)
        }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 10) {
            BrandLogoView(size: 28, cornerRadius: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text("ClipFlow")
                    .font(.subheadline.weight(.semibold))
                Text(appVersionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            VisualEffectBlur(material: .headerView, blendingMode: .withinWindow)
                .opacity(0.85)
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }

    private var appVersionLabel: String {
        AppVersion.displayLabel
    }

    private func settingsIcon(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedPane {
        case .dashboard:
            settingsScroll {
                VStack(alignment: .leading, spacing: 18) {
                    paneHeader(
                        pane: .dashboard,
                        subtitle: t(
                            "Saúde e desempenho do seu Mac em tempo real.",
                            "Real-time health and performance for your Mac."
                        ),
                        status: systemMetrics.isRunning ? t("Ao vivo", "Live") : t("Pausado", "Paused")
                    )
                    SystemDashboardView(metrics: systemMetrics, language: settings.language, showsHeader: false)
                }
            }
        case .menuBar:
            settingsScroll {
                VStack(alignment: .leading, spacing: 18) {
                    paneHeader(
                        pane: .menuBar,
                        subtitle: t(
                            "Escolha quais métricas ficam sempre visíveis e como cada uma aparece.",
                            "Choose which metrics stay visible and how each one appears."
                        )
                    )
                    MenuBarSettingsView(settings: settings)
                }
            }
        case .maintenance:
            settingsScroll {
                VStack(alignment: .leading, spacing: 18) {
                    paneHeader(
                        pane: .maintenance,
                        subtitle: t(
                            "Recupere espaço e entenda a memória sem interromper processos.",
                            "Reclaim space and understand memory without interrupting processes."
                        )
                    )
                    MaintenanceView(metrics: systemMetrics, settings: settings)
                }
            }
        case .general:
            settingsScroll { generalForm }
        case .voice:
            settingsScroll { voiceForm }
        case .intelligence:
            settingsScroll { intelligenceForm }
        case .hotkey:
            settingsScroll { hotkeyForm }
        case .ignoredApps:
            settingsScroll { ignoredAppsForm }
        case .permissions:
            settingsScroll { permissionsForm }
        case .about:
            settingsScroll { aboutForm }
        }
    }

    private func settingsScroll<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.automatic)
        .scrollDisabled(isHoveringIgnoredAppsGrid && selectedPane == .ignoredApps)
    }

    private func paneHeader(pane: SettingsPane, subtitle: String, status: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: pane.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(pane.tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(pane.title(for: settings.language))
                    .font(.title2.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let status {
                HStack(spacing: 6) {
                    Circle()
                        .fill(systemMetrics.isRunning ? Color.green : Color.secondary)
                        .frame(width: 7, height: 7)
                    Text(status)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.7), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    // MARK: - Forms

    private var generalForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .general,
                subtitle: t("Preferências principais do ClipFlow.", "Main ClipFlow preferences.")
            )

            Form {
                Section {
                    Picker(t("Limite do Histórico", "History Limit"), selection: $settings.historyLimit) {
                        Text("100").tag(100)
                        Text("500").tag(500)
                        Text("1000").tag(1000)
                    }

                    Picker(t("Idioma", "Language"), selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }

                    Picker(t("Aparência", "Appearance"), selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title(for: settings.language)).tag(appearance)
                        }
                    }
                }

                Section {
                    Toggle(t("Iniciar com o macOS", "Launch at Login"), isOn: launchAtLoginBinding)

                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Toggle(t("Pausar monitoramento", "Pause monitoring"), isOn: $settings.pauseMonitoring)
                    Toggle(t("Criptografia local (AES-GCM)", "Local encryption (AES-GCM)"), isOn: $settings.enableEncryption)
                } footer: {
                    Text(t(
                        "A criptografia protege o conteúdo salvo no histórico com AES-GCM no Keychain.",
                        "Encryption protects saved history content with AES-GCM via the Keychain."
                    ))
                }
            }
            .clipFlowSettingsFormStyle()
        }
    }

    private var voiceForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .voice,
                subtitle: t(
                    "Como o Clip escuta e responde por voz.",
                    "How Clip listens and answers by voice."
                )
            )

            Form {
                Section {
                    Toggle(t("Ativar comandos de voz", "Enable voice commands"), isOn: $settings.voiceControlEnabled)

                    Picker(t("Modo de ativação", "Activation mode"), selection: $settings.voiceActivationMode) {
                        ForEach(VoiceActivationMode.allCases) { mode in
                            Text(mode.title(for: settings.language)).tag(mode)
                        }
                    }
                } footer: {
                    Text(
                        settings.voiceActivationMode == .wakeWord
                            ? t(
                                "O microfone fica aberto aguardando a palavra de ativação — o indicador laranja do macOS permanece aceso.",
                                "The microphone stays open for the wake word — the macOS orange indicator stays on."
                            )
                            : t(
                                "Pressione ⌥⇧V, fale o comando e o microfone desliga sozinho.",
                                "Press ⌥⇧V, speak the command, and the microphone turns off by itself."
                            )
                    )
                }

                if settings.voiceActivationMode == .wakeWord {
                    Section {
                        TextField(t("Palavra de ativação", "Wake word"), text: $settings.voiceWakeWord)
                    }
                }

                Section {
                    Toggle(t("Som de confirmação", "Sound feedback"), isOn: $settings.voiceSoundFeedback)
                    Toggle(t("Respostas faladas", "Spoken responses"), isOn: $settings.voiceSpokenResponses)
                    TextField(t("Seu nome", "Your name"), text: $settings.userName, prompt: Text(t("como devo te chamar", "what should I call you")))
                }

                Section {
                    LabeledContent(t("Voz do Clip", "Clip's voice")) {
                        Text(t("Thalita (neural)", "Jenny (neural)"))
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text(t(
                        "Voz neural Microsoft Edge TTS. Offline, usa a voz do sistema.",
                        "Microsoft Edge neural TTS. Offline, falls back to the system voice."
                    ))
                }

                Section {
                    Text(voiceExamplesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if settings.voiceControlEnabled,
                   !permissionsManager.isMicrophoneGranted || !permissionsManager.isSpeechRecognitionGranted {
                    Section {
                        Label(
                            t(
                                "Conceda Microfone e Reconhecimento de Fala quando solicitado.",
                                "Grant Microphone and Speech Recognition when prompted."
                            ),
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                        .font(.callout)
                    }
                }
            }
            .clipFlowSettingsFormStyle()
        }
    }

    private var intelligenceForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .intelligence,
                subtitle: t(
                    "Modelo on-device, privado e generativo — com acessibilidade em primeiro plano.",
                    "On-device, private, generative model — accessibility first."
                )
            )

            modelStatusHero
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(t("Status do modelo", "Model status")): \(generativeStatusText)")
                .accessibilityHint(generativeStatusHint)

            Form {
                Section {
                    Toggle(t("Respostas generativas", "Generative answers"), isOn: $settings.generativeAnswersEnabled)
                        .accessibilityHint(t(
                            "Quando ativo, o Clip gera todas as falas com Apple Intelligence.",
                            "When on, Clip generates all speech with Apple Intelligence."
                        ))
                } footer: {
                    Text(t(
                        "O Clip usa o modelo gratuito do Apple Intelligence no seu Mac. Sem respostas fixas de conversa.",
                        "Clip uses the free Apple Intelligence model on your Mac. No hard-coded conversation replies."
                    ))
                }

                if settings.generativeAnswersEnabled {
                    Section {
                        Toggle(t("Contexto da web", "Web context"), isOn: $settings.generativeUseWebContext)
                            .accessibilityHint(t(
                                "Busca trechos gratuitos na internet antes de responder perguntas factuais.",
                                "Fetches free web snippets before answering factual questions."
                            ))

                        if settings.generativeUseWebContext {
                            Label {
                                Text(t(
                                    "Durante a consulta, o HUD mostra “Consultando a internet…”.",
                                    "While searching, the HUD shows “Searching the web…”."
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "globe")
                                    .foregroundStyle(.cyan)
                            }
                            .accessibilityLabel(t(
                                "Feedback visual ao consultar a internet ativado.",
                                "On-screen feedback while searching the web is enabled."
                            ))
                        }
                    } footer: {
                        Text(t(
                            "Com contexto da web, o Clip busca trechos gratuitos e passa para o modelo gerar respostas mais atuais. Links citados pedem confirmação antes de abrir.",
                            "With web context, Clip fetches free snippets for fresher answers. Cited links ask for confirmation before opening."
                        ))
                    }

                    Section {
                        Button {
                            generativeAnswers.refreshStatus(userName: settings.userName.isEmpty ? nil : settings.userName)
                        } label: {
                            Label(t("Atualizar status", "Refresh status"), systemImage: "arrow.clockwise")
                        }
                        .accessibilityHint(t(
                            "Verifica se o modelo Apple Intelligence está pronto.",
                            "Checks whether the Apple Intelligence model is ready."
                        ))

                        if generativeAnswers.status == .appleIntelligenceDisabled
                            || generativeAnswers.status == .downloading {
                            Button {
                                generativeAnswers.openAppleIntelligenceSettings()
                            } label: {
                                Label(
                                    t("Abrir Apple Intelligence…", "Open Apple Intelligence…"),
                                    systemImage: "gearshape.2"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityHint(t(
                                "Abre os Ajustes do Sistema para ativar ou baixar o modelo.",
                                "Opens System Settings to enable or download the model."
                            ))
                        }
                    }
                }
            }
            .clipFlowSettingsFormStyle()
        }
    }

    private var modelStatusHero: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [generativeStatusAccent.opacity(0.45), generativeStatusAccent.opacity(0.08)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 36
                        )
                    )
                    .frame(width: 64, height: 64)

                if generativeAnswers.status == .downloading {
                    ProgressView()
                        .controlSize(.regular)
                } else {
                    Image(systemName: generativeStatusSymbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(generativeStatusAccent)
                        .symbolEffect(.pulse, isActive: generativeAnswers.status == .available)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(t("Apple Intelligence", "Apple Intelligence"))
                    .font(.headline)

                Text(generativeStatusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(generativeStatusColor)

                Text(t(
                    "On-device · privado · sem custo de API",
                    "On-device · private · no API cost"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(generativeStatusAccent.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var hotkeyForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .hotkey,
                subtitle: t("Abertura rápida do painel do ClipFlow.", "Quick access to the ClipFlow panel.")
            )

            Form {
                Section {
                    LabeledContent(t("Atalho atual", "Current hotkey")) {
                        Text(settings.hotkeyDisplay)
                            .font(.body.monospaced().weight(.semibold))
                    }

                    Picker(t("Preset", "Preset"), selection: $selectedHotkeyPresetID) {
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
                }

                if selectedHotkeyPresetID == HotkeyPreset.customID {
                    Section {
                        Button(
                            isRecordingCustomHotkey
                                ? t("Pressione a combinação…", "Press key combination…")
                                : t("Gravar atalho", "Record shortcut")
                        ) {
                            if isRecordingCustomHotkey {
                                stopHotkeyRecording()
                            } else {
                                startHotkeyRecording()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t(
                                "Use ao menos uma tecla modificadora (Command, Option, Control ou Shift).",
                                "Use at least one modifier key (Command, Option, Control, or Shift)."
                            ))
                            if let hotkeyRecorderMessage {
                                Text(hotkeyRecorderMessage)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .clipFlowSettingsFormStyle()
        }
    }

    private var ignoredAppsForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .ignoredApps,
                subtitle: t(
                    "Apps sensíveis que o ClipFlow não deve monitorar.",
                    "Sensitive apps ClipFlow should not monitor."
                )
            )

            Form {
                Section {
                    HStack(spacing: 8) {
                        Button(t("Adicionar…", "Add…")) {
                            presentAddIgnoredAppsSheet()
                        }

                        Button(t("Remover", "Remove"), role: .destructive) {
                            removeSelectedIgnoredApp()
                        }
                        .disabled(selectedIgnoredAppBundleID == nil)

                        Spacer(minLength: 0)

                        if isLoadingAvailableApps {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    ignoredAppsGrid
                } footer: {
                    Text(t(
                        "Útil para gerenciadores de senha e apps com dados sensíveis na área de transferência.",
                        "Useful for password managers and apps with sensitive clipboard data."
                    ))
                }
            }
            .clipFlowSettingsFormStyle()
        }
    }

    private var permissionsForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .permissions,
                subtitle: t(
                    "Necessárias para hotkeys, colagem e análise de tela.",
                    "Required for hotkeys, pasting, and screen analysis."
                )
            )

            PermissionsView(permissionsManager: permissionsManager, settings: settings)
        }
    }

    private var aboutForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            paneHeader(
                pane: .about,
                subtitle: t(
                    "Versão, atualizações e informações do ClipFlow em um só lugar.",
                    "Version, updates, and ClipFlow information in one place."
                )
            )

            Form {
                Section {
                    HStack(spacing: 14) {
                        BrandLogoView(size: 56, cornerRadius: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ClipFlow")
                                .font(.title2.weight(.semibold))
                            Text(appVersionLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(t(
                                "Área de transferência nativa com assistente de voz.",
                                "Native clipboard manager with a voice assistant."
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }

                Section(t("Atualizações", "Updates")) {
                    AppUpdatePanel(
                        service: appUpdateService,
                        settings: settings,
                        showsAppIdentity: false,
                        isEmbedded: true
                    )

                    Toggle(
                        t("Verificar automaticamente ao abrir", "Check automatically on launch"),
                        isOn: Binding(
                            get: { appUpdateService.automaticChecksEnabled },
                            set: { appUpdateService.setAutomaticChecksEnabled($0) }
                        )
                    )
                }

                Section(t("Desenvolvedor", "Developer")) {
                    LabeledContent(t("Criado por", "Built by")) {
                        Text(DeveloperProfileCatalog.displayName)
                    }

                    Text(t(
                        "Projeto open source — feito para qualquer pessoa usar.",
                        "Open-source project — built for anyone to use."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Link(t("Abrir GitHub", "Open GitHub"), destination: githubURL)
                    Link(t("Abrir LinkedIn", "Open LinkedIn"), destination: linkedInURL)
                }

                Section {
                    Text(t(
                        "O Clip responde com Apple Intelligence on-device — privado, gratuito e generativo.",
                        "Clip answers with on-device Apple Intelligence — private, free, and generative."
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .clipFlowSettingsFormStyle()
        }
        .onAppear {
            if case .idle = appUpdateService.phase {
                Task { await appUpdateService.checkForUpdates(userInitiated: false) }
            }
        }
    }

    // MARK: - Voice / AI helpers

    private var voiceExamplesText: String {
        let prefix = settings.voiceActivationMode == .wakeWord ? "\(settings.voiceWakeWord), " : ""
        return t(
            "Exemplos: \"\(prefix)abra o Xcode\" · \"\(prefix)o que eu copiei\" · \"\(prefix)cole o item 2\" · \"\(prefix)quanto é 15 mais 7\" · \"\(prefix)veja o que está na tela\"",
            "Examples: \"\(prefix)open Xcode\" · \"\(prefix)what did I copy\" · \"\(prefix)paste item 2\" · \"\(prefix)what is 15 plus 7\" · \"\(prefix)what's on the screen\""
        )
    }

    private var generativeStatusText: String {
        switch generativeAnswers.status {
        case .available:
            return t("Pronto", "Ready")
        case .downloading:
            return t("Baixando modelo…", "Downloading model…")
        case .appleIntelligenceDisabled:
            return t("Apple Intelligence desativado", "Apple Intelligence off")
        case .deviceNotEligible:
            return t("Mac incompatível", "Mac not eligible")
        case .unavailable:
            return t("Indisponível", "Unavailable")
        case .unsupportedOS:
            return t("Requer macOS 26+", "Requires macOS 26+")
        }
    }

    private var generativeStatusHint: String {
        switch generativeAnswers.status {
        case .available:
            return t("O modelo está pronto para responder.", "The model is ready to answer.")
        case .downloading:
            return t("Aguarde o download do modelo nas Ajustes do Sistema.", "Wait for the model download in System Settings.")
        case .appleIntelligenceDisabled:
            return t("Ative o Apple Intelligence nas Ajustes do Sistema.", "Turn on Apple Intelligence in System Settings.")
        case .deviceNotEligible:
            return t("Este Mac não suporta Apple Intelligence.", "This Mac does not support Apple Intelligence.")
        case .unavailable:
            return t("Tente atualizar o status em instantes.", "Try refreshing the status shortly.")
        case .unsupportedOS:
            return t("Atualize o macOS para usar respostas generativas.", "Update macOS to use generative answers.")
        }
    }

    private var generativeStatusSymbol: String {
        switch generativeAnswers.status {
        case .available: return "checkmark.seal.fill"
        case .downloading: return "arrow.down.circle"
        case .appleIntelligenceDisabled: return "sparkles"
        case .deviceNotEligible: return "laptopcomputer.slash"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .unsupportedOS: return "macwindow.badge.plus"
        }
    }

    private var generativeStatusAccent: Color {
        switch generativeAnswers.status {
        case .available: return .cyan
        case .downloading: return .orange
        case .appleIntelligenceDisabled: return .orange
        case .deviceNotEligible: return .red
        case .unavailable: return .orange
        case .unsupportedOS: return .secondary
        }
    }

    private var generativeStatusColor: Color {
        switch generativeAnswers.status {
        case .available:
            return .secondary
        case .downloading, .appleIntelligenceDisabled, .deviceNotEligible, .unavailable, .unsupportedOS:
            return .orange
        }
    }

    // MARK: - Ignored apps

    private var addIgnoredAppsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("Adicionar App Ignorado", "Add Ignored App"))
                .font(.headline)

            TextField(t("Buscar por nome do app", "Search by app name"), text: $appSearchText)
                .textFieldStyle(.roundedBorder)

            if filteredAvailableApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(t("Nenhum app encontrado", "No apps found"))
                        .font(.subheadline.weight(.semibold))
                    Text(t("Tente outro nome de app.", "Try another app name."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 320)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary.opacity(0.35))
                )
            } else {
                List(filteredAvailableApps, selection: $selectedAvailableAppBundleID) { app in
                    ApplicationListRow(app: app, showBundleID: false)
                        .tag(app.bundleID)
                }
                .frame(minHeight: 320)
            }

            HStack {
                Text("\(filteredAvailableApps.count) \(t("apps encontrados", "apps found"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(t("Cancelar", "Cancel")) {
                    isAddIgnoredAppSheetPresented = false
                }

                Button(t("Adicionar", "Add")) {
                    addSelectedAvailableApp()
                    isAddIgnoredAppSheetPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAvailableApp == nil)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 440)
    }

    private var ignoredAppsGrid: some View {
        Group {
            if ignoredApplications.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("Nenhum app ignorado", "No ignored apps"))
                            .font(.subheadline.weight(.semibold))
                        Text(t("Clique em Adicionar para escolher apps.", "Click Add to choose apps."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVGrid(columns: ignoredGridColumns, spacing: 8) {
                            ForEach(ignoredApplications) { app in
                                IgnoredAppGridItem(
                                    app: app,
                                    isSelected: selectedIgnoredAppBundleID == app.bundleID
                                )
                                .id(app.bundleID)
                                .onTapGesture {
                                    selectedIgnoredAppBundleID = app.bundleID
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(height: ignoredAppsGridHeight)
                    .scrollIndicators(.visible)
                    .onHover { hovering in
                        isHoveringIgnoredAppsGrid = hovering
                    }
                    .onAppear {
                        scrollIgnoredAppsGridToTop(using: proxy)
                    }
                    .onChange(of: settings.ignoredBundleIDs, initial: false) { _, _ in
                        scrollIgnoredAppsGridToTop(using: proxy)
                    }
                }
            }
        }
    }

    private var ignoredGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8)
        ]
    }

    private var ignoredAppsGridHeight: CGFloat {
        let itemCount = ignoredApplications.count
        guard itemCount > 0 else { return 0 }
        let rows = Int(ceil(Double(itemCount) / 3.0))
        let visibleRows = min(rows, 3)
        return CGFloat(visibleRows) * 44 + CGFloat(max(visibleRows - 1, 0)) * 8 + 2
    }

    private var ignoredApplications: [InstalledApplication] {
        settings.ignoredBundleIDs.map { bundleID in
            if let known = availableApps.first(where: { $0.bundleID == bundleID }) {
                return known
            }
            let knownURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            return InstalledApplication(
                bundleID: bundleID,
                name: fallbackAppName(from: bundleID),
                appPath: knownURL?.path
            )
        }
    }

    private var filteredAvailableApps: [InstalledApplication] {
        let query = appSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ignored = Set(settings.ignoredBundleIDs)
        return availableApps.filter { app in
            guard !ignored.contains(app.bundleID) else { return false }
            guard !query.isEmpty else { return true }
            return app.name.lowercased().contains(query) || app.bundleID.lowercased().contains(query)
        }
    }

    private var selectedAvailableApp: InstalledApplication? {
        if let selectedAvailableAppBundleID,
           let app = filteredAvailableApps.first(where: { $0.bundleID == selectedAvailableAppBundleID }) {
            return app
        }
        if filteredAvailableApps.count == 1 {
            return filteredAvailableApps.first
        }
        return nil
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

    // MARK: - Actions

    private func syncHotkeyPresetState() {
        selectedHotkeyPresetID = HotkeyPreset
            .matching(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)?
            .id ?? HotkeyPreset.customID
    }

    private func presentAddIgnoredAppsSheet() {
        loadAvailableAppsIfNeeded()
        appSearchText = ""
        selectedAvailableAppBundleID = nil
        isAddIgnoredAppSheetPresented = true
    }

    private func loadAvailableAppsIfNeeded() {
        guard availableApps.isEmpty, !isLoadingAvailableApps else { return }
        isLoadingAvailableApps = true
        Task.detached(priority: .userInitiated) {
            let apps = discoverInstalledApplications()
            await MainActor.run {
                self.availableApps = apps
                self.isLoadingAvailableApps = false
            }
        }
    }

    private func addSelectedAvailableApp() {
        guard let selectedAvailableApp else { return }
        var updated = settings.ignoredBundleIDs
        updated.append(selectedAvailableApp.bundleID)
        settings.ignoredBundleIDs = updated
        selectedIgnoredAppBundleID = selectedAvailableApp.bundleID
    }

    private func removeSelectedIgnoredApp() {
        guard let selectedIgnoredAppBundleID else { return }
        settings.ignoredBundleIDs.removeAll { $0 == selectedIgnoredAppBundleID }
        self.selectedIgnoredAppBundleID = nil
    }

    private func fallbackAppName(from bundleID: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: appURL),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return bundleID
            .split(separator: ".")
            .last
            .map(String.init)?
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? bundleID
    }

    private func scrollIgnoredAppsGridToTop(using proxy: ScrollViewProxy) {
        guard let firstBundleID = ignoredApplications.first?.bundleID else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(firstBundleID, anchor: .top)
        }
    }

    private func startHotkeyRecording() {
        stopHotkeyRecording()
        hotkeyRecorderMessage = nil
        isRecordingCustomHotkey = true

        hotkeyRecorderMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard self.isRecordingCustomHotkey else { return event }

            let keyCode = UInt32(event.keyCode)
            let modifiers = HotkeyFormatter.carbonModifiers(from: event.modifierFlags)

            guard HotkeyFormatter.isValidShortcut(keyCode: keyCode, modifiers: modifiers) else {
                self.hotkeyRecorderMessage = self.t(
                    "Atalho inválido. Use uma tecla com modificador.",
                    "Invalid shortcut. Use a key with a modifier."
                )
                NSSound.beep()
                self.stopHotkeyRecording()
                return nil
            }

            self.settings.hotkeyCode = keyCode
            self.settings.hotkeyModifiers = modifiers
            self.selectedHotkeyPresetID = HotkeyPreset.customID
            self.onRebindHotkey()
            self.hotkeyRecorderMessage = self.t("Atalho atualizado.", "Shortcut updated.")
            self.stopHotkeyRecording()
            return nil
        } as AnyObject
    }

    private func stopHotkeyRecording() {
        isRecordingCustomHotkey = false
        if let hotkeyRecorderMonitor {
            NSEvent.removeMonitor(hotkeyRecorderMonitor)
            self.hotkeyRecorderMonitor = nil
        }
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }
}

private struct InstalledApplication: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let appPath: String?

    var id: String { bundleID }

    var icon: NSImage {
        if let appPath {
            return NSWorkspace.shared.icon(forFile: appPath)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

private struct ApplicationListRow: View {
    let app: InstalledApplication
    let showBundleID: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.subheadline)
                    .lineLimit(1)

                if showBundleID {
                    Text(app.bundleID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct IgnoredAppGridItem: View {
    let app: InstalledApplication
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            Text(app.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private func discoverInstalledApplications() -> [InstalledApplication] {
    let fileManager = FileManager.default
    let appDirectories: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/Applications/Utilities"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    ]

    var seenBundleIDs: Set<String> = []
    var discovered: [InstalledApplication] = []

    for directory in appDirectories where fileManager.fileExists(atPath: directory.path) {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            continue
        }

        for case let url as URL in enumerator {
            guard url.pathExtension == "app" else { continue }
            guard let bundle = Bundle(url: url),
                  let bundleID = bundle.bundleIdentifier?.lowercased(),
                  !bundleID.isEmpty,
                  !seenBundleIDs.contains(bundleID) else {
                continue
            }

            let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent

            seenBundleIDs.insert(bundleID)
            discovered.append(InstalledApplication(bundleID: bundleID, name: displayName, appPath: url.path))
        }
    }

    return discovered.sorted {
        let lhs = $0.name.localizedCaseInsensitiveCompare($1.name)
        if lhs == .orderedSame {
            return $0.bundleID < $1.bundleID
        }
        return lhs == .orderedAscending
    }
}
