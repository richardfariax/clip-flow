import Foundation

/// Responde perguntas sobre o desenvolvedor do app com dados locais confiáveis.
enum DeveloperKnowledgeService {
    enum FollowUpAction: Equatable {
        case searchWeb(String)
        case openLinkedIn
    }

    struct Answer: Equatable {
        let message: String
        let followUp: FollowUpAction?
    }

    enum Topic: Equatable {
        case workplace
        case son
        case wife
        case father
        case mother
        case brother
        case fullName
        case profile
        case linkedIn
    }

    /// Indica se a pergunta é sobre a vida pessoal/profissional do desenvolvedor.
    static func isDeveloperPersonalQuestion(_ normalized: String) -> Bool {
        classify(normalized) != nil
    }

    static func answer(question: String, portuguese: Bool) -> Answer? {
        let normalized = VoiceCommandParser.normalize(question)
        guard let topic = classify(normalized) else { return nil }
        return buildAnswer(for: topic, portuguese: portuguese)
    }

    // MARK: - Classificação

    static func classify(_ normalized: String) -> Topic? {
        guard referencesDeveloper(normalized) else { return nil }

        if isLinkedInRequest(normalized) { return .linkedIn }
        if isWorkplaceQuestion(normalized) { return .workplace }
        if isFamilyQuestion(normalized, markers: ["filho", "filha", "son", "daughter"]) { return .son }
        if isFamilyQuestion(normalized, markers: ["esposa", "mulher", "wife", "marido", "conjuge"]) { return .wife }
        if isFamilyQuestion(normalized, markers: ["pai", "father", "papai"]) { return .father }
        if isFamilyQuestion(normalized, markers: ["mae", "mother", "mamae"]) { return .mother }
        if isFamilyQuestion(normalized, markers: ["irmao", "irma", "brother", "sister"]) { return .brother }
        if isFullNameQuestion(normalized) { return .fullName }
        if isProfileQuestion(normalized) { return .profile }

        return nil
    }

    private static func referencesDeveloper(_ normalized: String) -> Bool {
        if DeveloperProfileCatalog.nameAliases.contains(where: { normalized.contains($0) }) {
            return true
        }
        if DeveloperProfileCatalog.companyAliases.contains(where: { normalized.contains($0) }) {
            return true
        }

        let developerContext = ["desenvolvedor", "criador", "dono", "developer", "creator", "author"]
        let personalContext = [
            "trabalha", "empresa", "filho", "filha", "esposa", "mulher", "pai", "mae",
            "irmao", "irma", "familia", "nome completo", "linkedin", "perfil"
        ]

        let hasDeveloperWord = developerContext.contains { normalized.contains($0) }
        let hasPersonalWord = personalContext.contains { normalized.contains($0) }
        return hasDeveloperWord && hasPersonalWord
    }

    private static func isLinkedInRequest(_ normalized: String) -> Bool {
        normalized.contains("linkedin") || normalized.contains("perfil profissional")
    }

    private static func isWorkplaceQuestion(_ normalized: String) -> Bool {
        let signals = [
            "onde trabalha", "onde trabalho", "onde ele trabalha", "onde richard trabalha",
            "empresa", "trabalha", "works", "work at", "company", "emprego", "empregado"
        ]
        return signals.contains { normalized.contains($0) }
            || DeveloperProfileCatalog.companyAliases.contains { normalized.contains($0) }
    }

    private static func isFamilyQuestion(_ normalized: String, markers: [String]) -> Bool {
        markers.contains { normalized.contains($0) }
    }

    private static func isFullNameQuestion(_ normalized: String) -> Bool {
        normalized.contains("nome completo") || normalized.contains("full name")
    }

    private static func isProfileQuestion(_ normalized: String) -> Bool {
        let signals = [
            "quem e", "quem eh", "quem e o", "quem e a", "me fale sobre", "me conta sobre",
            "who is", "tell me about", "sobre o richard", "sobre richard"
        ]
        return signals.contains { normalized.contains($0) }
    }

    // MARK: - Respostas

    private static func buildAnswer(for topic: Topic, portuguese: Bool) -> Answer {
        switch topic {
        case .workplace:
            return Answer(
                message: portuguese
                    ? "O \(DeveloperProfileCatalog.displayName) trabalha na \(DeveloperProfileCatalog.company). Quer que eu pesquise sobre a empresa na internet?"
                    : "\(DeveloperProfileCatalog.displayName) works at \(DeveloperProfileCatalog.company). Want me to search for the company online?",
                followUp: .searchWeb("\(DeveloperProfileCatalog.company) empresa")
            )

        case .son:
            return Answer(
                message: portuguese
                    ? "O filho do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.son)."
                    : "\(DeveloperProfileCatalog.displayName)'s son is \(DeveloperProfileCatalog.son).",
                followUp: nil
            )

        case .wife:
            return Answer(
                message: portuguese
                    ? "A esposa do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.wife)."
                    : "\(DeveloperProfileCatalog.displayName)'s wife is \(DeveloperProfileCatalog.wife).",
                followUp: nil
            )

        case .father:
            return Answer(
                message: portuguese
                    ? "O pai do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.father)."
                    : "\(DeveloperProfileCatalog.displayName)'s father is \(DeveloperProfileCatalog.father).",
                followUp: nil
            )

        case .mother:
            return Answer(
                message: portuguese
                    ? "A mãe do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.mother)."
                    : "\(DeveloperProfileCatalog.displayName)'s mother is \(DeveloperProfileCatalog.mother).",
                followUp: nil
            )

        case .brother:
            return Answer(
                message: portuguese
                    ? "O irmão do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.brother)."
                    : "\(DeveloperProfileCatalog.displayName)'s brother is \(DeveloperProfileCatalog.brother).",
                followUp: nil
            )

        case .fullName:
            return Answer(
                message: portuguese
                    ? "O nome completo do desenvolvedor é \(DeveloperProfileCatalog.fullName)."
                    : "The developer's full name is \(DeveloperProfileCatalog.fullName).",
                followUp: nil
            )

        case .linkedIn:
            return Answer(
                message: portuguese
                    ? "O LinkedIn do \(DeveloperProfileCatalog.displayName) é \(DeveloperProfileCatalog.linkedInURL). Quer que eu abra?"
                    : "\(DeveloperProfileCatalog.displayName)'s LinkedIn is \(DeveloperProfileCatalog.linkedInURL). Want me to open it?",
                followUp: .openLinkedIn
            )

        case .profile:
            return Answer(
                message: portuguese
                    ? "\(DeveloperProfileCatalog.fullName) é o desenvolvedor do ClipFlow, trabalha na \(DeveloperProfileCatalog.company) e é casado com \(DeveloperProfileCatalog.wife). Tem um filho, \(DeveloperProfileCatalog.son). Quer saber mais no LinkedIn?"
                    : "\(DeveloperProfileCatalog.fullName) is ClipFlow's developer, works at \(DeveloperProfileCatalog.company), and is married to \(DeveloperProfileCatalog.wife). They have a son, \(DeveloperProfileCatalog.son). Want to know more on LinkedIn?",
                followUp: .openLinkedIn
            )
        }
    }
}
