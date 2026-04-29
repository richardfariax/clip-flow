import AppKit
import Combine
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var modelContainer: ModelContainer?

    private var settings = AppSettings()
    private var cryptoService = LocalCryptoService()
    private var permissionsManager = PermissionsManager()
    private var launchAtLoginManager = LaunchAtLoginManager()

    private var storageService: ClipboardStorageService?
    private var monitorService: ClipboardMonitorService?
    private var pasteService: PasteService?

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
        configureMenuBar()
        configureHotkey()
        configureApplicationActivationTracking()
        bindSettings()

        monitorService?.start()
        permissionsManager.refresh()
        permissionsManager.promptOnFirstLaunchIfNeeded()

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
            }
        )
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
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            isPausedProvider: { [weak self] in
                self?.settings.pauseMonitoring ?? false
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
    }

    private func bindSettings() {
        settings.$pauseMonitoring
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarController?.refreshPauseState()
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
        if let existing = settingsWindowController {
            existing.showWindow(nil)
            existing.window?.makeKeyAndOrderFront(nil)
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
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
