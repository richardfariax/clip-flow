import Foundation
import AppKit

/// App instalado em /Applications ou ~/Applications.
struct InstalledApp: Identifiable, Hashable {
    let url: URL
    let name: String
    let bundleIdentifier: String?
    let version: String?
    let bytes: UInt64

    var id: URL { url }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

/// Sobras de um app (caches, preferências, suporte etc.).
struct AppLeftovers {
    let app: InstalledApp
    let items: [CleanFileItem]
    var bytes: UInt64 { items.reduce(0) { $0 + $1.bytes } }
}

@MainActor
final class AppInventoryService: ObservableObject {
    @Published private(set) var apps: [InstalledApp] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isUninstalling = false
    @Published private(set) var leftovers: AppLeftovers?
    @Published private(set) var errorMessage: String?

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            let loaded = await Task.detached(priority: .utility) { Self.loadApps() }.value
            apps = loaded
            isLoading = false
        }
    }

    /// Encontra sobras do app (não remove nada ainda).
    func findLeftovers(for app: InstalledApp) {
        Task {
            let found = await Task.detached(priority: .utility) { Self.leftovers(for: app) }.value
            leftovers = AppLeftovers(app: app, items: found)
        }
    }

    func dismissLeftovers() {
        leftovers = nil
    }

    /// Move o app e as sobras selecionadas para a Lixeira.
    func uninstall(app: InstalledApp, leftoverURLs: [URL]) {
        guard !isUninstalling else { return }
        isUninstalling = true
        errorMessage = nil

        Task {
            let outcome = await Task.detached(priority: .utility) {
                FileSweeper.trash(urls: [app.url] + leftoverURLs)
            }.value
            if !outcome.failures.isEmpty {
                errorMessage = outcome.failures.joined(separator: "\n")
            }
            leftovers = nil
            isUninstalling = false
            refresh()
        }
    }

    // MARK: - Carregamento

    nonisolated static func loadApps() -> [InstalledApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]

        var found: [InstalledApp] = []
        for root in roots {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for url in urls where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let info = bundle?.infoDictionary
                let name = (info?["CFBundleDisplayName"] as? String)
                    ?? (info?["CFBundleName"] as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                found.append(InstalledApp(
                    url: url,
                    name: name,
                    bundleIdentifier: bundle?.bundleIdentifier,
                    version: info?["CFBundleShortVersionString"] as? String,
                    bytes: FileSweeper.allocatedSize(of: url)
                ))
            }
        }
        return found.sorted { $0.bytes > $1.bytes }
    }

    nonisolated static func leftovers(for app: InstalledApp) -> [CleanFileItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let containers = [
            "Application Support",
            "Caches",
            "Preferences",
            "Logs",
            "Saved Application State",
            "Containers",
            "HTTPStorages",
            "WebKit"
        ].map { library.appendingPathComponent($0, isDirectory: true) }

        var matches: [CleanFileItem] = []
        let bundleID = app.bundleIdentifier?.lowercased()
        let appName = app.name.lowercased()

        for container in containers {
            guard let urls = try? FileManager.default.contentsOfDirectory(
                at: container, includingPropertiesForKeys: nil
            ) else { continue }
            for url in urls {
                let candidate = url.lastPathComponent.lowercased()
                let matchesBundle = bundleID.map { candidate.contains($0) } ?? false
                // Nome exato evita falsos positivos com nomes genéricos.
                let matchesName = appName.count >= 4
                    && (candidate == appName || candidate == appName + ".plist")
                guard matchesBundle || matchesName else { continue }
                // Nunca sugere sobras do próprio ClipFlow.
                if candidate.contains("clipflow") { continue }
                matches.append(CleanFileItem(
                    url: url,
                    bytes: FileSweeper.allocatedSize(of: url),
                    modifiedAt: nil
                ))
            }
        }
        return matches.sorted { $0.bytes > $1.bytes }
    }
}
