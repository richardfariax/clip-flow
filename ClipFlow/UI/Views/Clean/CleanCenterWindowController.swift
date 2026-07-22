import AppKit
import SwiftUI

/// Janela dedicada do centro de limpeza (CleanFlow).
@MainActor
final class CleanCenterWindowController {
    private var windowController: NSWindowController?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        if let window = windowController?.window {
            window.orderFrontRegardless()
            window.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: CleanCenterView(settings: settings))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.title = settings.text(ptBR: "CleanFlow", en: "CleanFlow")
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 1180, height: 740))
        window.minSize = NSSize(width: 1080, height: 700)
        window.center()

        let controller = NSWindowController(window: window)
        windowController = controller
        controller.showWindow(nil)
        window.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}
