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

    private var settingsWindowController: NSWindowController?

    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard configurePersistence() else {
            fatalError("Falha ao iniciar persistência do ClipFlow")
        }

        configureServices()
        configurePanel()
        configureMenuBar()
        configureHotkey()
        bindSettings()

        monitorService?.start()
        permissionsManager.refresh()

        if settings.launchAtLogin {
            try? launchAtLoginManager.setEnabled(true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        monitorService?.stop()
        NotificationCenter.default.removeObserver(self)
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
                self.panelController?.close()
                self.panelViewModel?.pasteSelectedItem()
            }
        )
    }

    private func configureMenuBar() {
        menuBarController = MenuBarController(
            onOpenPanel: { [weak self] in
                self?.captureFrontmostExternalApplication()
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
            }
            .store(in: &cancellables)
    }

    @objc private func handleHotkeyPress() {
        if panelController?.isVisible == true {
            panelController?.close()
            return
        }

        captureFrontmostExternalApplication()
        panelController?.show()
        panelViewModel?.refresh()
    }

    private func captureFrontmostExternalApplication() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        guard frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        lastExternalApplication = frontmost
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
        window.title = "Preferências"
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
