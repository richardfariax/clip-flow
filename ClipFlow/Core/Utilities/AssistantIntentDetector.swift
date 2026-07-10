import Foundation

/// Detecta perguntas sobre o próprio assistente Clip (identidade, criador, capacidades).
/// Evita que caiam na busca genérica na internet e retornem respostas aleatórias.
enum AssistantIntent: Equatable {
    case aboutAssistant
    case aboutDeveloper
    case openDeveloperProfile
    case help
}

enum AssistantIntentDetector {
    static func detect(normalized: String) -> AssistantIntent? {
        if isDeveloperProfileRequest(normalized) {
            return .openDeveloperProfile
        }
        if isAboutDeveloper(normalized) {
            return .aboutDeveloper
        }
        if isAboutAssistant(normalized) {
            return .aboutAssistant
        }
        if isHelp(normalized) {
            return .help
        }
        return nil
    }

    // MARK: - Developer

    static func isAboutDeveloper(_ normalized: String) -> Bool {
        let directPhrases = [
            "quem desenvolveu", "quem te desenvolveu", "quem te criou", "quem criou voce",
            "quem e seu criador", "quem e o seu criador", "quem e o criador",
            "quem e o dono", "quem e seu dono", "quem fez voce", "quem te fez",
            "quem te programou", "quem programou voce", "quem e seu desenvolvedor",
            "quem e o desenvolvedor", "quem e o seu desenvolvedor",
            "por quem voce foi desenvolvido", "por quem voce foi criado", "por quem voce foi feito",
            "por quem voce foi programado", "voce foi desenvolvido por quem",
            "voce foi criado por quem", "voce foi feito por quem",
            "por quem foi desenvolvido", "por quem foi criado", "por quem foi feito",
            "de quem voce e", "de quem voce e filho",
            "who created you", "who developed you", "who made you", "who built you",
            "who programmed you", "who is your creator", "who is your developer",
            "who is your author", "who made clip", "who created clip"
        ]
        if directPhrases.contains(where: { normalized.contains($0) }) {
            return true
        }

        guard referencesAssistant(normalized) else { return false }

        let creatorSignals = [
            "desenvolv", "criou", "criado", "criada", "criador", "criadora",
            "fez", "feito", "feita", "program", "autor", "dono",
            "develop", "created", "maker", "built", "author", "owner", "creator"
        ]
        guard creatorSignals.contains(where: { normalized.contains($0) }) else { return false }

        if normalized.contains("por quem") || normalized.contains("quem ") {
            return true
        }

        return normalized.contains("quem e") && creatorSignals.contains(where: { normalized.contains($0) })
    }

    // MARK: - Assistant identity

    static func isAboutAssistant(_ normalized: String) -> Bool {
        let phrases = [
            "quem e voce", "quem es voce", "o que voce e", "o que e voce",
            "quem e o clip", "quem e clip", "o que e o clip", "o que e clip",
            "qual seu nome", "qual e seu nome", "qual o seu nome", "como voce se chama",
            "pra que voce serve", "para que voce serve", "qual sua funcao",
            "who are you", "what are you", "what is clip", "who is clip",
            "what is your name", "what do you do"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    // MARK: - Help

    static func isHelp(_ normalized: String) -> Bool {
        let phrases = [
            "o que voce sabe fazer", "o que voce pode fazer", "o que voce pode fazer por mim",
            "o que pode fazer por mim", "o que voce faz", "o que voce faz por mim",
            "quais comandos", "lista de comandos", "listar comandos", "quais suas funcoes",
            "me ajude", "me ajuda", "ajuda", "help", "what can you do", "what can you do for me",
            "list commands"
        ]
        return phrases.contains { normalized.contains($0) }
    }

    // MARK: - Developer profile

    static func isDeveloperProfileRequest(_ normalized: String) -> Bool {
        let developerWords = ["dono", "criador", "desenvolvedor", "richard", "seu", "dele", "developer", "creator", "owner", "your"]
        return normalized.contains("linkedin")
            && developerWords.contains(where: { normalized.contains($0) })
    }

    // MARK: - Helpers

    private static func referencesAssistant(_ normalized: String) -> Bool {
        let markers = [
            "voce", "voce foi", " te ", "te.", "te,", "te?", "te!",
            "clip", "clipflow", "assistente",
            " you ", "your ", "yourself", "you're", "you are"
        ]
        return markers.contains { normalized.contains($0) }
            || normalized.hasPrefix("voce ")
            || normalized.hasPrefix("te ")
    }
}
