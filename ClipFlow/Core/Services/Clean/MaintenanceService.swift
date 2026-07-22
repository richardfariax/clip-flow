import Foundation

/// Tarefa de manutenção no estilo CleanMyMac.
struct MaintenanceTask: Identifiable {
    let id: String
    let titlePT: String
    let titleEN: String
    let detailPT: String
    let detailEN: String
    let systemImage: String
    /// Comando shell executado; tarefas com `needsAdmin` rodam em um único
    /// "do shell script ... with administrator privileges" (1 prompt só).
    let command: String
    let needsAdmin: Bool
}

@MainActor
final class MaintenanceService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastOutcomePT: String?
    @Published private(set) var lastOutcomeEN: String?

    let tasks: [MaintenanceTask] = [
        MaintenanceTask(
            id: "flushDNS",
            titlePT: "Limpar cache de DNS", titleEN: "Flush DNS cache",
            detailPT: "Resolve sites que não carregam após trocas de rede",
            detailEN: "Fixes sites that fail to load after network changes",
            systemImage: "network",
            command: "dscacheutil -flushcache; killall -HUP mDNSResponder",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "spotlight",
            titlePT: "Reindexar Spotlight", titleEN: "Reindex Spotlight",
            detailPT: "Reconstrói o índice de busca — a reindexação leva um tempo",
            detailEN: "Rebuilds the search index — reindexing takes a while",
            systemImage: "magnifyingglass",
            command: "mdutil -E / >/dev/null 2>&1",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "purgeRAM",
            titlePT: "Liberar memória inativa", titleEN: "Free up inactive memory",
            detailPT: "Executa purge para liberar RAM em cache",
            detailEN: "Runs purge to release cached RAM",
            systemImage: "memorychip",
            command: "purge",
            needsAdmin: true
        ),
        MaintenanceTask(
            id: "launchServices",
            titlePT: "Reconstruir Launch Services", titleEN: "Rebuild Launch Services",
            detailPT: "Corrige apps duplicados no menu \"Abrir com\"",
            detailEN: "Fixes duplicate apps in the \"Open With\" menu",
            systemImage: "menucard",
            command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user >/dev/null 2>&1",
            needsAdmin: false
        )
    ]

    /// Executa as tarefas selecionadas. As que exigem admin disparam o prompt
    /// de senha padrão do macOS (uma vez, com os comandos agrupados).
    func run(taskIDs: Set<String>) {
        guard !taskIDs.isEmpty, !isRunning else { return }
        isRunning = true
        lastOutcomePT = nil
        lastOutcomeEN = nil

        let selected = tasks.filter { taskIDs.contains($0.id) }
        Task {
            let failures = await Task.detached(priority: .userInitiated) { () -> [String] in
                var failures: [String] = []

                let userCommands = selected.filter { !$0.needsAdmin }.map(\.command)
                for command in userCommands {
                    if !Self.runShell(command) { failures.append(command) }
                }

                let adminCommands = selected.filter(\.needsAdmin).map(\.command)
                if !adminCommands.isEmpty {
                    let joined = adminCommands.joined(separator: "; ")
                    if !Self.runShellAsAdmin(joined) {
                        failures.append("admin: \(joined)")
                    }
                }
                return failures
            }.value

            if failures.isEmpty {
                lastOutcomePT = "Tarefas concluídas com sucesso."
                lastOutcomeEN = "Tasks completed successfully."
            } else {
                lastOutcomePT = "Algumas tarefas falharam ou foram canceladas."
                lastOutcomeEN = "Some tasks failed or were cancelled."
            }
            isRunning = false
        }
    }

    // MARK: - Execução

    private nonisolated static func runShell(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Usa osascript para obter o prompt de autenticação nativo do macOS.
    private nonisolated static func runShellAsAdmin(_ command: String) -> Bool {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
