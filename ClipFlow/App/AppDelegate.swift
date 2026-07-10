import AppKit
import Carbon
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settingsContentSize = NSSize(width: 880, height: 780)
    private var modelContainer: ModelContainer?

    private var settings = AppSettings()
    private var cryptoService = LocalCryptoService()
    private var permissionsManager = PermissionsManager()
    private var launchAtLoginManager = LaunchAtLoginManager()

    private var storageService: ClipboardStorageService?
    private var monitorService: ClipboardMonitorService?
    private var pasteService: PasteService?
    private var screenshotService: ScreenshotService?
    private var screenAnalysisService: ScreenAnalysisService?

    private var voiceCommandService: VoiceCommandService?
    private var voiceCommandExecutor: VoiceCommandExecutor?
    private var voiceHUDController: VoiceHUDController?
    private var spokenResponseService = SpokenResponseService()
    private var pendingFollowUp: VoiceCommandExecutor.FollowUp?

    private var hotkeyManager = HotkeyManager()
    private var panelViewModel: ClipboardPanelViewModel?
    private var panelController: ClipboardPanelController?
    private var menuBarController: MenuBarController?
    private var lastExternalApplication: NSRunningApplication?
    private var panelTargetApplication: NSRunningApplication?

    private var settingsWindowController: NSWindowController?

    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard configurePersistence() else {
            presentStartupFailureAndTerminate()
            return
        }

        configureServices()
        configurePanel()
        configureVoiceControl()
        configureMenuBar()
        configureHotkey()
        configureApplicationActivationTracking()
        bindSettings()

        monitorService?.start()
        permissionsManager.refresh()
        permissionsManager.promptOnFirstLaunchIfNeeded()
        // O bind de settings.$voiceControlEnabled inicia o serviço de voz se habilitado.

        if settings.launchAtLogin {
            do {
                try launchAtLoginManager.setEnabled(true)
            } catch {
                NSLog("[ClipFlow] Falha ao ativar 'Launch at Login' no startup: \(error.localizedDescription)")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        monitorService?.stop()
        voiceCommandService?.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func configurePersistence() -> Bool {
        do {
            modelContainer = try ModelContainer(for: ClipboardItemEntity.self)
            return true
        } catch {
            NSLog("[ClipFlow] Falha ao criar ModelContainer: \(error.localizedDescription)")
            return false
        }
    }

    private func presentStartupFailureAndTerminate() {
        let message = settings.text(
            ptBR: "Não foi possível iniciar a persistência local do ClipFlow.",
            en: "ClipFlow could not initialize local persistence."
        )
        let details = settings.text(
            ptBR: "O app será encerrado para evitar comportamento inconsistente.",
            en: "The app will now quit to avoid inconsistent behavior."
        )

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "ClipFlow"
        alert.informativeText = "\(message)\n\n\(details)"
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func configureServices() {
        guard let modelContainer else { return }
        let modelContext = ModelContext(modelContainer)

        let storage = ClipboardStorageService(modelContext: modelContext, settings: settings, cryptoService: cryptoService)
        let monitor = ClipboardMonitorService(storageService: storage, settings: settings)
        let paste = PasteService(permissionsManager: permissionsManager)

        storageService = storage
        monitorService = monitor
        pasteService = paste
        screenshotService = ScreenshotService()
        screenAnalysisService = ScreenAnalysisService()
    }

    private func configurePanel() {
        guard let storageService, let pasteService else { return }

        let viewModel = ClipboardPanelViewModel(
            storageService: storageService,
            pasteService: pasteService,
            targetApplicationProvider: { [weak self] in
                self?.lastExternalApplication
            }
        )
        panelViewModel = viewModel

        let panelView = ClipboardPanelView(viewModel: viewModel, settings: settings) { [weak self] in
            self?.panelController?.close()
        }

        panelController = ClipboardPanelController(
            rootView: panelView,
            onMoveSelection: { [weak self] moveUp in
                self?.panelViewModel?.moveSelection(upward: moveUp)
            },
            onConfirmSelection: { [weak self] in
                guard let self else { return }
                let targetApplication = self.panelTargetApplication
                self.panelController?.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    self.panelViewModel?.pasteSelectedItem(targetApplication: targetApplication)
                }
            },
            onToggleFavoriteSelection: { [weak self] in
                self?.panelViewModel?.toggleFavoriteForSelectedItem()
            },
            onTogglePinSelection: { [weak self] in
                self?.panelViewModel?.togglePinForSelectedItem()
            },
            onCopySelection: { [weak self] in
                _ = self?.panelViewModel?.copySelectedItemToPasteboard()
            },
            onSelectFilter: { [weak self] filter in
                self?.panelViewModel?.setFilter(filter)
            },
            onStackSelection: { [weak self] in
                self?.panelViewModel?.addSelectedToStack()
            }
        )
    }

    private func configureVoiceControl() {
        guard let panelViewModel, let pasteService, let screenshotService, let screenAnalysisService else { return }

        let hud = VoiceHUDController()
        hud.isSoundEnabled = { [weak self] in
            self?.settings.voiceSoundFeedback ?? true
        }
        voiceHUDController = hud

        let executor = VoiceCommandExecutor(
            settings: settings,
            panelViewModel: panelViewModel,
            pasteService: pasteService,
            screenshotService: screenshotService,
            screenAnalysisService: screenAnalysisService,
            targetApplicationProvider: { [weak self] in
                self?.lastExternalApplication
            },
            openPanel: { [weak self] in
                self?.openPanelFromExternalTrigger()
            },
            closePanel: { [weak self] in
                self?.panelController?.close()
            },
            openSettings: { [weak self] in
                self?.openSettingsWindow()
            },
            hideOverlayForCapture: { [weak self] in
                self?.voiceHUDController?.hide()
            }
        )
        voiceCommandExecutor = executor

        let voiceService = VoiceCommandService(settings: settings)
        voiceService.onWakeWordDetected = { [weak self] in
            guard let self else { return }
            let hint = self.pendingFollowUp != nil
                ? self.settings.text(ptBR: "Pode responder...", en: "Go ahead...")
                : self.settings.text(ptBR: "Ouvindo... diga um comando", en: "Listening... say a command")
            self.voiceHUDController?.showListening(hint: hint)
        }
        voiceService.onPartialCommand = { [weak self] transcript in
            self?.voiceHUDController?.updateTranscript(transcript)
        }
        voiceService.onCommandCaptured = { [weak self] rawText in
            guard let self else { return }
            // Silencia o microfone imediatamente para não captar a própria resposta falada.
            self.voiceCommandService?.pauseForSpeechOutput()
            if let followUp = self.pendingFollowUp {
                self.pendingFollowUp = nil
                self.voiceCommandExecutor?.handleFollowUpResponse(followUp, answer: rawText) { [weak self] feedback in
                    self?.presentFeedback(feedback)
                }
            } else {
                self.voiceCommandExecutor?.execute(rawText: rawText) { [weak self] feedback in
                    self?.presentFeedback(feedback)
                }
            }
        }
        voiceService.onCaptureCancelled = { [weak self] in
            guard let self else { return }
            if self.pendingFollowUp != nil {
                // Usuário não respondeu à pergunta: encerra a conversa em silêncio.
                self.pendingFollowUp = nil
                self.voiceHUDController?.hide()
                self.voiceCommandService?.resumeAfterSpeechOutput()
                return
            }
            self.voiceHUDController?.showFeedback(
                message: self.settings.text(
                    ptBR: "Nenhum comando reconhecido. Tente de novo.",
                    en: "No command recognized. Try again."
                ),
                success: false
            )
        }
        voiceCommandService = voiceService
    }

    /// Mostra o feedback, fala a resposta e mantém o overlay até o fim da fala.
    /// Se o assistente fez uma pergunta, volta a ouvir a resposta em seguida.
    private func presentFeedback(_ feedback: VoiceCommandExecutor.Feedback) {
        voiceHUDController?.showFeedback(message: feedback.message, success: feedback.success, autoHide: false)

        let proceed: () -> Void = { [weak self] in
            guard let self else { return }
            if let followUp = feedback.followUp {
                self.pendingFollowUp = followUp
                self.voiceCommandService?.beginFollowUpCapture()
            } else {
                self.voiceHUDController?.hide()
            }
        }

        if settings.voiceSpokenResponses {
            spokenResponseService.speak(
                feedback.message,
                languageCode: settings.text(ptBR: "pt-BR", en: "en-US")
            ) { [weak self] in
                self?.voiceCommandService?.resumeAfterSpeechOutput()
                proceed()
            }
        } else {
            let readingTime = min(max(Double(feedback.message.count) * 0.045, 2.0), 6.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + readingTime) { [weak self] in
                self?.voiceCommandService?.resumeAfterSpeechOutput()
                proceed()
            }
        }
    }

    private func openPanelFromExternalTrigger() {
        captureFrontmostExternalApplication()
        panelTargetApplication = lastExternalApplication
        panelController?.show()
        panelViewModel?.refresh()
    }

    private func configureMenuBar() {
        menuBarController = MenuBarController(
            onOpenPanel: { [weak self] in
                self?.captureFrontmostExternalApplication()
                self?.panelTargetApplication = self?.lastExternalApplication
                self?.panelController?.show()
                self?.panelViewModel?.refresh()
            },
            onOpenSettings: { [weak self] in
                self?.openSettingsWindow()
            },
            onTogglePause: { [weak self] newValue in
                self?.settings.pauseMonitoring = newValue
            },
            onToggleVoice: { [weak self] newValue in
                self?.settings.voiceControlEnabled = newValue
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            isPausedProvider: { [weak self] in
                self?.settings.pauseMonitoring ?? false
            },
            isVoiceEnabledProvider: { [weak self] in
                self?.settings.voiceControlEnabled ?? false
            },
            languageProvider: { [weak self] in
                self?.settings.language ?? .system
            }
        )
    }

    private func configureHotkey() {
        hotkeyManager.register(keyCode: settings.hotkeyCode, modifiers: settings.hotkeyModifiers)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyPress),
            name: HotkeyManager.hotkeyPressedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVoiceHotkeyPress),
            name: HotkeyManager.voiceHotkeyPressedNotification,
            object: nil
        )
    }

    /// Aplica o modo de ativação de voz: escuta contínua (wake word) ou
    /// push-to-talk (⌥⇧V) em que o microfone só liga durante a captura.
    private func applyVoiceActivationConfiguration() {
        voiceCommandService?.stop()
        voiceHUDController?.hide()
        hotkeyManager.unregisterVoiceHotkey()
        menuBarController?.refreshVoiceState()

        guard settings.voiceControlEnabled else { return }

        switch settings.voiceActivationMode {
        case .wakeWord:
            voiceCommandService?.start()
        case .hotkey:
            hotkeyManager.registerVoiceHotkey(
                keyCode: UInt32(kVK_ANSI_V),
                modifiers: UInt32(optionKey | shiftKey)
            )
        }
    }

    @objc private func handleVoiceHotkeyPress() {
        guard settings.voiceControlEnabled, settings.voiceActivationMode == .hotkey else { return }
        voiceCommandService?.beginManualCapture()
    }

    private func bindSettings() {
        settings.$pauseMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController?.refreshPauseState()
            }
            .store(in: &cancellables)

        settings.$voiceControlEnabled
            .combineLatest(settings.$voiceActivationMode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.applyVoiceActivationConfiguration()
            }
            .store(in: &cancellables)

        settings.$hotkeyCode
            .combineLatest(settings.$hotkeyModifiers)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] code, modifiers in
                self?.hotkeyManager.register(keyCode: code, modifiers: modifiers)
            }
            .store(in: &cancellables)

        settings.$appearance
            .receive(on: DispatchQueue.main)
            .sink { appearance in
                switch appearance {
                case .system:
                    NSApp.appearance = nil
                case .light:
                    NSApp.appearance = NSAppearance(named: .aqua)
                case .dark:
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
                self.menuBarController?.refreshAppearance()
            }
            .store(in: &cancellables)

        settings.$language
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController?.refreshLocalizedContent()
            }
            .store(in: &cancellables)
    }

    private func configureApplicationActivationTracking() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        captureFrontmostExternalApplication()
    }

    @objc private func handleHotkeyPress() {
        if panelController?.isVisible == true {
            panelController?.close()
            return
        }

        captureFrontmostExternalApplication()
        panelTargetApplication = lastExternalApplication
        panelController?.show()
        panelViewModel?.refresh()
    }

    private func captureFrontmostExternalApplication() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        guard frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastExternalApplication = frontmost
    }

    @objc private func handleDidActivateApplication(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            permissionsManager.refresh()
            return
        }
        lastExternalApplication = app
        if panelController?.isVisible == false {
            panelTargetApplication = app
        }
    }

    private func openSettingsWindow() {
        panelController?.close()

        if let existing = settingsWindowController {
            existing.showWindow(nil)
            if let window = existing.window {
                window.setContentSize(settingsContentSize)
                window.minSize = settingsContentSize
                window.maxSize = settingsContentSize
                positionSettingsWindow(window)
                window.level = .floating
                window.orderFrontRegardless()
                window.makeKey()
            }
            NotificationCenter.default.post(name: Notification.Name("clipflow.settings.scrollToTop"), object: nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            settings: settings,
            permissionsManager: permissionsManager,
            launchManager: launchAtLoginManager,
            onRebindHotkey: { [weak self] in
                guard let self else { return }
                self.hotkeyManager.register(keyCode: self.settings.hotkeyCode, modifiers: self.settings.hotkeyModifiers)
            }
        )

        let hosting = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hosting)
        window.title = settings.text(ptBR: "Preferências", en: "Preferences")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.isMovable = true
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.setContentSize(settingsContentSize)
        window.minSize = settingsContentSize
        window.maxSize = settingsContentSize
        positionSettingsWindow(window)

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        positionSettingsWindow(window)
        window.orderFrontRegardless()
        window.makeKey()
        NotificationCenter.default.post(name: Notification.Name("clipflow.settings.scrollToTop"), object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func positionSettingsWindow(_ window: NSWindow) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: settingsContentSize)).size
        var origin = NSPoint(
            x: frame.midX - frameSize.width / 2,
            y: frame.midY - frameSize.height / 2
        )

        let maxX = frame.maxX - frameSize.width
        let maxY = frame.maxY - frameSize.height
        origin.x = min(max(origin.x, frame.minX), maxX)
        origin.y = min(max(origin.y, frame.minY), maxY)

        window.setFrame(NSRect(origin: origin, size: frameSize), display: true)
    }
}
