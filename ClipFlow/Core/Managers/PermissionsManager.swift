import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import Speech

/// Identidade da instalação. Update/reinstall/path novo pode invalidar TCC;
/// flags de "já pedi" em UserDefaults ficam obsoletos.
private struct AppInstallIdentity: Codable, Equatable {
    var marketingVersion: String
    var build: String
    var bundlePath: String
    var executableFingerprint: String

    static func current() -> AppInstallIdentity {
        let executableURL = Bundle.main.executableURL
        var fingerprint = "unknown"
        if let executableURL,
           let values = try? executableURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) {
            let size = values.fileSize ?? 0
            let mtime = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            fingerprint = "\(size)-\(mtime)"
        }

        return AppInstallIdentity(
            marketingVersion: AppVersion.marketing,
            build: AppVersion.build,
            bundlePath: Bundle.main.bundlePath,
            executableFingerprint: fingerprint
        )
    }
}

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published private(set) var isInputMonitoringGranted: Bool = CGPreflightListenEventAccess()
    @Published private(set) var isMicrophoneGranted: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published private(set) var isSpeechRecognitionGranted: Bool = SFSpeechRecognizer.authorizationStatus() == .authorized
    @Published private(set) var isScreenCaptureGranted: Bool = false

    /// Permissões críticas ausentes (colar + hotkeys).
    @Published private(set) var missingRequiredPermissions: Bool = false

    /// Update/reinstall detectado com permissões críticas ausentes.
    @Published private(set) var requiresRegrantAfterUpdate: Bool = false

    private let defaults = UserDefaults.standard
    private let identityKey = "clipflow.permissions.installIdentity"
    private let promptedAccessibilityKey = "clipflow.permissions.prompted.accessibility"
    private let promptedInputMonitoringKey = "clipflow.permissions.prompted.inputMonitoring"

    var hasRequiredPermissions: Bool {
        isAccessibilityGranted && isInputMonitoringGranted
    }

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
        isInputMonitoringGranted = CGPreflightListenEventAccess()
        isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        isSpeechRecognitionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
        isScreenCaptureGranted = screenCaptureAccessGranted()
        missingRequiredPermissions = !hasRequiredPermissions

        if hasRequiredPermissions {
            requiresRegrantAfterUpdate = false
        }
    }

    /// Valida TCC na abertura; re-solicita se a instalação mudou ou faltam permissões críticas.
    func validatePermissionsOnLaunch() {
        refresh()

        let currentIdentity = AppInstallIdentity.current()
        let previousIdentity = loadStoredIdentity()
        let identityChanged = previousIdentity != currentIdentity

        if identityChanged {
            clearPromptedFlags()

            let hadPreviousInstall = previousIdentity != nil
            if hadPreviousInstall && !hasRequiredPermissions {
                requiresRegrantAfterUpdate = true
            }
        }

        saveIdentity(currentIdentity)
        promptForMissingRequiredPermissions(force: identityChanged && previousIdentity != nil)
    }

    func requestScreenCapture() {
        ScreenAnalysisService.requestScreenCaptureAccessIfNeeded()
        scheduleRefreshes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isScreenCaptureGranted else { return }
            self.openScreenCaptureSettings()
        }
    }

    func openScreenCaptureSettings() {
        openPrivacySettings(urls: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        scheduleRefreshes()
    }

    func requestVoicePermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                DispatchQueue.main.async {
                    self?.refresh()
                    completion(speechStatus == .authorized && micGranted)
                }
            }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        scheduleRefreshes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isAccessibilityGranted else { return }
            self.openAccessibilitySettings()
        }
    }

    func requestInputMonitoring() {
        let granted = CGRequestListenEventAccess()
        scheduleRefreshes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if !granted || !self.isInputMonitoringGranted {
                self.openInputMonitoringSettings()
            }
        }
    }

    func openAccessibilitySettings() {
        openPrivacySettings(urls: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        scheduleRefreshes()
    }

    func openInputMonitoringSettings() {
        openPrivacySettings(urls: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_InputMonitoring",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Keyboard",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Keyboard",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        scheduleRefreshes()
    }

    // MARK: - Private

    private func promptForMissingRequiredPermissions(force: Bool) {
        let shouldPromptAccessibility =
            !isAccessibilityGranted && (force || !defaults.bool(forKey: promptedAccessibilityKey))
        let shouldPromptInputMonitoring =
            !isInputMonitoringGranted && (force || !defaults.bool(forKey: promptedInputMonitoringKey))

        if shouldPromptAccessibility {
            defaults.set(true, forKey: promptedAccessibilityKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.requestAccessibility()
            }
        }

        if shouldPromptInputMonitoring {
            defaults.set(true, forKey: promptedInputMonitoringKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.requestInputMonitoring()
            }
        }
    }

    private func clearPromptedFlags() {
        defaults.removeObject(forKey: promptedAccessibilityKey)
        defaults.removeObject(forKey: promptedInputMonitoringKey)
    }

    private func loadStoredIdentity() -> AppInstallIdentity? {
        guard let data = defaults.data(forKey: identityKey) else { return nil }
        return try? JSONDecoder().decode(AppInstallIdentity.self, from: data)
    }

    private func saveIdentity(_ identity: AppInstallIdentity) {
        guard let data = try? JSONEncoder().encode(identity) else { return }
        defaults.set(data, forKey: identityKey)
    }

    private func screenCaptureAccessGranted() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return false
    }

    private func openPrivacySettings(urls: [String]) {
        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func scheduleRefreshes() {
        refresh()
        let delays: [TimeInterval] = [0.6, 1.5, 3.0, 5.0, 8.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }
}
