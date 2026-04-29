import AppKit
import Foundation

@MainActor
final class ClipboardMonitorService {
    private let pasteboard: NSPasteboard
    private let storageService: ClipboardStorageService
    private let settings: AppSettings
    private let ownBundleID = Bundle.main.bundleIdentifier?.lowercased()

    private var timer: Timer?
    private var lastChangeCount: Int
    private var shouldIgnoreNextChange = false

    init(
        pasteboard: NSPasteboard = .general,
        storageService: ClipboardStorageService,
        settings: AppSettings
    ) {
        self.pasteboard = pasteboard
        self.storageService = storageService
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProgrammaticWrite),
            name: .clipboardDidProgrammaticWrite,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func start() {
        stop()

        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboard()
            }
        }
        timer?.tolerance = 0.15
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func pollPasteboard() {
        guard !settings.pauseMonitoring else {
            return
        }

        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else {
            return
        }
        lastChangeCount = currentCount

        if shouldIgnoreNextChange {
            shouldIgnoreNextChange = false
            return
        }

        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard shouldCapture(sourceBundleID: sourceBundleID) else {
            return
        }

        if let snapshot = captureSnapshot() {
            storageService.insert(snapshot: snapshot, sourceBundleID: sourceBundleID)
            NotificationCenter.default.post(name: .clipboardDidUpdate, object: nil)
        }
    }

    private func shouldCapture(sourceBundleID: String?) -> Bool {
        guard let sourceBundleID else { return true }
        let normalized = sourceBundleID.lowercased()

        if normalized == ownBundleID {
            return false
        }

        return !settings.ignoredBundleIDs.contains(normalized)
    }

    private func captureSnapshot() -> ClipboardSnapshot? {
        if let imageData = imagePayload() {
            return ClipboardSnapshot(
                kind: .image,
                textSubtype: nil,
                payload: imageData,
                contentHash: ClipboardContentClassifier.sha256Hex(imageData),
                createdAt: Date()
            )
        }

        if let text = pasteboard.string(forType: .string) {
            guard !text.isEmpty else { return nil }
            guard let data = text.data(using: .utf8) else { return nil }

            return ClipboardSnapshot(
                kind: .text,
                textSubtype: ClipboardContentClassifier.classifyText(text),
                payload: data,
                contentHash: ClipboardContentClassifier.sha256Hex(data),
                createdAt: Date()
            )
        }

        return nil
    }

    private func imagePayload() -> Data? {
        guard let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    @objc private func handleProgrammaticWrite() {
        shouldIgnoreNextChange = true
    }
}
