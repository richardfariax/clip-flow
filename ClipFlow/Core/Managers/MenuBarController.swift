import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private enum ItemTag: Int {
        case openPanel = 1000
        case togglePause = 1001
        case settings = 1002
        case quit = 1003
    }

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let onOpenPanel: () -> Void
    private let onOpenSettings: () -> Void
    private let onTogglePause: (Bool) -> Void
    private let onQuit: () -> Void
    private let isPausedProvider: () -> Bool
    private let languageProvider: () -> AppLanguage

    init(
        onOpenPanel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onTogglePause: @escaping (Bool) -> Void,
        onQuit: @escaping () -> Void,
        isPausedProvider: @escaping () -> Bool,
        languageProvider: @escaping () -> AppLanguage
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onOpenPanel = onOpenPanel
        self.onOpenSettings = onOpenSettings
        self.onTogglePause = onTogglePause
        self.onQuit = onQuit
        self.isPausedProvider = isPausedProvider
        self.languageProvider = languageProvider
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func refreshPauseState() {
        guard let pauseItem = menu.item(withTag: ItemTag.togglePause.rawValue) else { return }
        pauseItem.state = isPausedProvider() ? .on : .off
    }

    func refreshAppearance() {
        applyStatusItemIcon()
    }

    func refreshLocalizedContent() {
        guard let openPanel = menu.item(withTag: ItemTag.openPanel.rawValue),
              let pause = menu.item(withTag: ItemTag.togglePause.rawValue),
              let settings = menu.item(withTag: ItemTag.settings.rawValue),
              let quit = menu.item(withTag: ItemTag.quit.rawValue) else {
            return
        }

        openPanel.title = t("Abrir ClipFlow", "Open ClipFlow")
        pause.title = t("Pausar Monitoramento", "Pause Monitoring")
        settings.title = t("Preferências...", "Preferences...")
        quit.title = t("Sair do ClipFlow", "Quit ClipFlow")
    }

    private func configureStatusItem() {
        applyStatusItemIcon()
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = menu
    }

    private func applyStatusItemIcon() {
        if let button = statusItem.button {
            if let menuBarLogo = NSImage(named: menuBarLogoAssetName(for: button.effectiveAppearance)) {
                menuBarLogo.size = NSSize(width: 18, height: 18)
                menuBarLogo.isTemplate = false
                button.image = menuBarLogo
            } else {
                button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipFlow")
            }
        }
    }

    private func menuBarLogoAssetName(for appearance: NSAppearance) -> String {
        let best = appearance.bestMatch(from: [.darkAqua, .aqua])
        return best == .darkAqua ? "ClipFlowLogoDark" : "ClipFlowLogoLight"
    }

    private func configureMenu() {
        menu.autoenablesItems = false

        let openPanelItem = NSMenuItem(title: t("Abrir ClipFlow", "Open ClipFlow"), action: #selector(openPanel), keyEquivalent: "")
        openPanelItem.target = self
        openPanelItem.tag = ItemTag.openPanel.rawValue
        menu.addItem(openPanelItem)

        let pauseItem = NSMenuItem(title: t("Pausar Monitoramento", "Pause Monitoring"), action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = ItemTag.togglePause.rawValue
        pauseItem.state = isPausedProvider() ? .on : .off
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: t("Preferências...", "Preferences..."), action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.tag = ItemTag.settings.rawValue
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: t("Sair do ClipFlow", "Quit ClipFlow"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.tag = ItemTag.quit.rawValue
        menu.addItem(quitItem)
    }

    @objc private func openPanel() {
        onOpenPanel()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func togglePause() {
        let updated = !isPausedProvider()
        onTogglePause(updated)
        refreshPauseState()
    }

    @objc private func quitApp() {
        onQuit()
    }

    private func t(_ pt: String, _ en: String) -> String {
        languageProvider().text(ptBR: pt, en: en)
    }
}
