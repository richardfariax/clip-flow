import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import Speech

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published private(set) var isInputMonitoringGranted: Bool = CGPreflightListenEventAccess()
    @Published private(set) var isMicrophoneGranted: Bool = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published private(set) var isSpeechRecognitionGranted: Bool = SFSpeechRecognizer.authorizationStatus() == .authorized

    private let defaults = UserDefaults.standard
    private let promptedAccessibilityKey = "clipflow.permissions.prompted.accessibility"
    private let promptedInputMonitoringKey = "clipflow.permissions.prompted.inputMonitoring"

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
        isInputMonitoringGranted = CGPreflightListenEventAccess()
        isMicrophoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        isSpeechRecognitionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
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
        openSettings(urls: [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
        ])
        scheduleRefreshes()
    }

    func openInputMonitoringSettings() {
        openSettings(urls: [
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

    func promptOnFirstLaunchIfNeeded() {
        refresh()

        let shouldPromptAccessibility = !defaults.bool(forKey: promptedAccessibilityKey) && !isAccessibilityGranted
        let shouldPromptInputMonitoring = !defaults.bool(forKey: promptedInputMonitoringKey) && !isInputMonitoringGranted

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

    private func openSettings(urls: [String]) {
        for rawURL in urls {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func scheduleRefreshes() {
        refresh()
        let delays: [TimeInterval] = [0.6, 1.5, 3.0, 5.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }
}
