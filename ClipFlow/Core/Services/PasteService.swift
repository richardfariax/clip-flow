import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PasteService {
    private let permissionsManager: PermissionsManager
    private let focusRetryDelay: TimeInterval = 0.05
    private let initialPasteDelay: TimeInterval = 0.09
    private let maxFocusRetries: Int = 8

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

        let target = resolveTargetApplication(from: targetApplication)
        if let target {
            target.activate(options: [.activateAllWindows])
        }

        pasteWithFocusRetry(targetApplication: target, attempt: 0, completion: completion)
    }

    private func resolveTargetApplication(from targetApplication: NSRunningApplication?) -> NSRunningApplication? {
        guard let targetApplication else { return nil }
        guard targetApplication.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
        guard !targetApplication.isTerminated else { return nil }
        return targetApplication
    }

    private func pasteWithFocusRetry(
        targetApplication: NSRunningApplication?,
        attempt: Int,
        completion: ((Bool) -> Void)?
    ) {
        let delay = attempt == 0 ? initialPasteDelay : focusRetryDelay

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else {
                completion?(false)
                return
            }

            guard let targetApplication else {
                completion?(self.triggerCommandV())
                return
            }

            if targetApplication.isTerminated {
                completion?(self.triggerCommandV())
                return
            }

            let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let hasFocus = frontmostPID == targetApplication.processIdentifier

            if !hasFocus, attempt < self.maxFocusRetries {
                if attempt == 2 || attempt == 5 {
                    targetApplication.activate(options: [.activateAllWindows])
                }
                self.pasteWithFocusRetry(
                    targetApplication: targetApplication,
                    attempt: attempt + 1,
                    completion: completion
                )
                return
            }

            let postedToTarget = self.triggerCommandV(to: targetApplication.processIdentifier)
            completion?(postedToTarget)
        }
    }

    private func triggerCommandV(to processIdentifier: pid_t? = nil) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        if let processIdentifier {
            keyDown.postToPid(processIdentifier)
            keyUp.postToPid(processIdentifier)
        } else {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }

        return true
    }
}
