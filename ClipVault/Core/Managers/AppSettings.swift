import Carbon
import Foundation

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Sistema"
        case .light:
            return "Claro"
        case .dark:
            return "Escuro"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let historyLimit = "historyLimit"
        static let pauseMonitoring = "pauseMonitoring"
        static let enableEncryption = "enableEncryption"
        static let ignoredBundleIDs = "ignoredBundleIDs"
        static let hotkeyCode = "hotkeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let launchAtLogin = "launchAtLogin"
        static let appearance = "appearance"
    }

    @Published var historyLimit: Int {
        didSet {
            let normalized = Self.normalizedHistoryLimit(historyLimit)
            if historyLimit != normalized {
                historyLimit = normalized
                return
            }
            userDefaults.set(historyLimit, forKey: Keys.historyLimit)
        }
    }

    @Published var pauseMonitoring: Bool {
        didSet { userDefaults.set(pauseMonitoring, forKey: Keys.pauseMonitoring) }
    }

    @Published var enableEncryption: Bool {
        didSet { userDefaults.set(enableEncryption, forKey: Keys.enableEncryption) }
    }

    @Published var launchAtLogin: Bool {
        didSet { userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var ignoredBundleIDs: [String] {
        didSet {
            let normalized = Self.normalizedBundleIDs(ignoredBundleIDs)
            if ignoredBundleIDs != normalized {
                ignoredBundleIDs = normalized
                return
            }
            userDefaults.set(ignoredBundleIDs, forKey: Keys.ignoredBundleIDs)
        }
    }

    @Published var hotkeyCode: UInt32 {
        didSet {
            let normalized = Self.normalizedHotkeyCode(hotkeyCode)
            if hotkeyCode != normalized {
                hotkeyCode = normalized
                return
            }
            userDefaults.set(Int(hotkeyCode), forKey: Keys.hotkeyCode)
        }
    }

    @Published var hotkeyModifiers: UInt32 {
        didSet {
            let normalized = Self.normalizedHotkeyModifiers(hotkeyModifiers)
            if hotkeyModifiers != normalized {
                hotkeyModifiers = normalized
                return
            }
            userDefaults.set(Int(hotkeyModifiers), forKey: Keys.hotkeyModifiers)
        }
    }

    @Published var appearance: AppAppearance {
        didSet { userDefaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let userDefaults: UserDefaults

    var hotkeyDisplay: String {
        HotkeyFormatter.displayString(keyCode: hotkeyCode, modifiers: hotkeyModifiers)
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let savedHistoryLimit = userDefaults.object(forKey: Keys.historyLimit) as? Int ?? 500
        historyLimit = Self.normalizedHistoryLimit(savedHistoryLimit)

        pauseMonitoring = userDefaults.object(forKey: Keys.pauseMonitoring) as? Bool ?? false
        enableEncryption = userDefaults.object(forKey: Keys.enableEncryption) as? Bool ?? false
        launchAtLogin = userDefaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false

        if let savedIgnored = userDefaults.object(forKey: Keys.ignoredBundleIDs) as? [String], !savedIgnored.isEmpty {
            ignoredBundleIDs = Self.normalizedBundleIDs(savedIgnored)
        } else {
            ignoredBundleIDs = Self.normalizedBundleIDs([
                "com.1password.1password",
                "com.apple.keychainaccess",
                "com.lastpass.LastPass",
                "com.bitwarden.desktop",
                "org.keepassxc.keepassxc"
            ])
        }

        let savedHotkeyCode = UInt32(userDefaults.object(forKey: Keys.hotkeyCode) as? Int ?? Int(kVK_ANSI_V))
        hotkeyCode = Self.normalizedHotkeyCode(savedHotkeyCode)

        let savedModifiers = UInt32(userDefaults.object(forKey: Keys.hotkeyModifiers) as? Int ?? optionKey)
        hotkeyModifiers = Self.normalizedHotkeyModifiers(savedModifiers)

        if let storedAppearanceRaw = userDefaults.string(forKey: Keys.appearance),
           let storedAppearance = AppAppearance(rawValue: storedAppearanceRaw) {
            appearance = storedAppearance
        } else {
            appearance = .system
        }
    }

    private static func normalizedHistoryLimit(_ value: Int) -> Int {
        min(max(value, 50), 5000)
    }

    private static func normalizedBundleIDs(_ value: [String]) -> [String] {
        var seen: Set<String> = []
        var normalized: [String] = []

        for item in value {
            let cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
            seen.insert(cleaned)
            normalized.append(cleaned)
        }

        return normalized
    }

    private static func normalizedHotkeyCode(_ value: UInt32) -> UInt32 {
        if value == 0 {
            return UInt32(kVK_ANSI_V)
        }
        return value
    }

    private static func normalizedHotkeyModifiers(_ value: UInt32) -> UInt32 {
        if value == 0 {
            return UInt32(optionKey)
        }
        return value
    }
}
