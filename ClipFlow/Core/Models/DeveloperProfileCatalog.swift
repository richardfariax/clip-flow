import Foundation

/// Dados pessoais e profissionais do desenvolvedor do ClipFlow.
/// Fonte autoritativa local — não vem da internet.
enum DeveloperProfileCatalog {
    static let displayName = "Richard Farias"
    static let fullName = "Richard Farias Marcos Júnior"
    static let linkedInURL = "https://www.linkedin.com/in/richardfariasss/"

    static let company = "HighSoft"
    static let son = "Anthony Farias"
    static let wife = "Mayara Marques"
    static let father = "Richard Farias Marcos"
    static let mother = "Nilceia Cardoso Correa Marcos"
    static let brother = "Gabriel Cardoso Correa"

    /// Aliases normalizados (sem acento, minúsculo) para reconhecer o desenvolvedor na fala.
    static let nameAliases: [String] = [
        "richard", "farias", "marcos junior", "richard farias",
        "richard farias marcos", "richard farias marcos junior"
    ]

    static let companyAliases: [String] = ["highsoft", "high soft"]
}
