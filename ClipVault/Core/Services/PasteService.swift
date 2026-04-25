import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PasteService {
    private let permissionsManager: PermissionsManager

    init(permissionsManager: PermissionsManager) {
        self.permissionsManager = permissionsManager
    }

    func paste(
        item: DecodedClipboardItem,
        targetApplication: NSRunningApplication?,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard permissionsManager.isAccessibilityGranted else {
            completion?(false)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            guard let text = item.text else {
                completion?(false)
                return
            }
            pasteboard.setString(text, forType: .string)
        case .image:
            guard let image = item.image else {
                completion?(false)
                return
            }
            pasteboard.writeObjects([image])
        }

        NotificationCenter.default.post(name: .clipboardDidProgrammaticWrite, object: nil)

        if let targetApplication,
           targetApplication.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApplication.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else {
                completion?(false)
                return
            }
            completion?(self.triggerCommandV())
        }
    }

    private func triggerCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
