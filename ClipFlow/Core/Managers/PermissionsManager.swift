import AppKit
import ApplicationServices
import Foundation

@MainActor
final class PermissionsManager: ObservableObject {
    @Published private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published private(set) var isInputMonitoringGranted: Bool = CGPreflightListenEventAccess()

    func refresh() {
        isAccessibilityGranted = AXIsProcessTrusted()
        isInputMonitoringGranted = CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func requestInputMonitoring() {
        let _ = CGRequestListenEventAccess()
        refresh()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_InputMonitoring") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
