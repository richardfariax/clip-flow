import AppKit
import Foundation

@MainActor
final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private let onOpenPanel: () -> Void
    private let onOpenSettings: () -> Void
    private let onTogglePause: (Bool) -> Void
    private let onQuit: () -> Void
    private let isPausedProvider: () -> Bool

    init(
        onOpenPanel: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onTogglePause: @escaping (Bool) -> Void,
        onQuit: @escaping () -> Void,
        isPausedProvider: @escaping () -> Bool
    ) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.onOpenPanel = onOpenPanel
        self.onOpenSettings = onOpenSettings
        self.onTogglePause = onTogglePause
        self.onQuit = onQuit
        self.isPausedProvider = isPausedProvider
        super.init()

        configureStatusItem()
        configureMenu()
    }

    func refreshPauseState() {
        guard let pauseItem = menu.item(withTag: 1001) else { return }
        pauseItem.state = isPausedProvider() ? .on : .off
    }

    func refreshAppearance() {
        applyStatusItemIcon()
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

        let openPanelItem = NSMenuItem(title: "Abrir ClipFlow", action: #selector(openPanel), keyEquivalent: "")
        openPanelItem.target = self
        menu.addItem(openPanelItem)

        let pauseItem = NSMenuItem(title: "Pausar Monitoramento", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = 1001
        pauseItem.state = isPausedProvider() ? .on : .off
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Preferências...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Sair do ClipFlow", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
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
}
