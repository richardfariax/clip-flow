import AppKit
import Carbon
import SwiftUI

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ClipboardPanelController {
    private let panel: FloatingPanel
    private let onMoveSelection: (Bool) -> Void
    private let onConfirmSelection: () -> Void
    private var keyMonitor: Any?

    var isVisible: Bool {
        panel.isVisible
    }

    init(
        rootView: ClipboardPanelView,
        onMoveSelection: @escaping (Bool) -> Void,
        onConfirmSelection: @escaping () -> Void
    ) {
        self.onMoveSelection = onMoveSelection
        self.onConfirmSelection = onConfirmSelection

        let hosting = NSHostingView(rootView: rootView)

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 700),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentView = hosting
    }

    func toggle() {
        panel.isVisible ? close() : show()
    }

    func show() {
        installKeyMonitorIfNeeded()
        centerOnActiveScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        panel.orderOut(nil)
    }

    private func centerOnActiveScreen() {
        let screen = NSApp.keyWindow?.screen ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let origin = NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.panel.isVisible, event.window == self.panel else {
                return event
            }

            switch Int(event.keyCode) {
            case kVK_UpArrow:
                self.onMoveSelection(true)
                return nil
            case kVK_DownArrow:
                self.onMoveSelection(false)
                return nil
            case kVK_Return, kVK_ANSI_KeypadEnter:
                self.onConfirmSelection()
                return nil
            case kVK_Escape:
                self.close()
                return nil
            default:
                return event
            }
        }
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }
}
