import Foundation

/// Locais de execução tipicamente usados por adware.
private let suspiciousPathFragments = [
    "/tmp/", "/private/tmp/", "/var/folders/", "/.hidden", "/downloads/"
]

/// Prefixos de labels de fornecedores conhecidos (lista básica, não exaustiva).
private let knownVendorPrefixes = [
    "com.apple.", "com.google.", "com.microsoft.", "com.adobe.",
    "com.docker.", "com.spotify.", "org.mozilla.", "com.dropbox.",
    "com.logi.", "com.jetbrains.", "com.macpaw.", "com.1password."
]

/// Achado da revisão de proteção. Não é um antivírus: apenas sinaliza
/// itens de inicialização com características típicas de adware para revisão manual.
struct ProtectionFinding: Identifiable {
    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let item: StartupItem
    let severity: Severity
    let reasonPT: String
    let reasonEN: String

    var id: URL { item.url }
}

@MainActor
final class ProtectionService: ObservableObject {
    @Published private(set) var findings: [ProtectionFinding] = []
    @Published private(set) var reviewedCount = 0
    @Published private(set) var isScanning = false

    var warningCount: Int {
        findings.filter { $0.severity == .warning }.count
    }

    func scan(completion: (() -> Void)? = nil) {
        guard !isScanning else { return }
        isScanning = true

        Task {
            let outcome = await Task.detached(priority: .utility) { () -> (findings: [ProtectionFinding], total: Int) in
                let items = StartupItemsService.loadStartupItems()
                let findings = items.compactMap(Self.evaluate)
                return (findings, items.count)
            }.value
            findings = outcome.findings.sorted { $0.severity > $1.severity }
            reviewedCount = outcome.total
            isScanning = false
            completion?()
        }
    }

    /// Move o plist sinalizado para a Lixeira (somente agentes do usuário).
    func quarantine(_ finding: ProtectionFinding) {
        guard finding.item.isRemovable else { return }
        _ = FileSweeper.trash(urls: [finding.item.url])
        findings.removeAll { $0.id == finding.id }
    }

    // MARK: - Heurísticas

    nonisolated static func evaluate(_ item: StartupItem) -> ProtectionFinding? {
        // Binário rodando de local temporário/oculto: sinal clássico de adware.
        if let program = item.programPath?.lowercased(),
           suspiciousPathFragments.contains(where: { program.contains($0) }) {
            return ProtectionFinding(
                item: item,
                severity: .warning,
                reasonPT: "Executável em local temporário ou incomum",
                reasonEN: "Executable in a temporary or unusual location"
            )
        }

        // Programa referenciado não existe mais: item quebrado.
        if let program = item.programPath, !FileManager.default.fileExists(atPath: program) {
            return ProtectionFinding(
                item: item,
                severity: .info,
                reasonPT: "Item quebrado: o programa referenciado não existe",
                reasonEN: "Broken item: referenced program no longer exists"
            )
        }

        // Terceiro desconhecido: apenas informativo, para revisão.
        let label = item.label.lowercased()
        if !knownVendorPrefixes.contains(where: { label.hasPrefix($0) }) && item.domain != .userAgent {
            return ProtectionFinding(
                item: item,
                severity: .info,
                reasonPT: "Item de terceiros fora da lista de fornecedores conhecidos",
                reasonEN: "Third-party item not in the known vendor list"
            )
        }

        return nil
    }
}
