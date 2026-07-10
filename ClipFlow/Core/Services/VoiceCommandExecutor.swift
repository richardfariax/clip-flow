import AppKit
import Foundation

/// Conecta comandos de voz reconhecidos às ações do app.
@MainActor
final class VoiceCommandExecutor {
    /// Ação pendente que aguarda a resposta falada do usuário (sem wake word).
    enum FollowUp {
        case webSearch(String)
        case openURL(String)
    }

    static let developerName = DeveloperProfileCatalog.displayName
    static let developerLinkedInURL = DeveloperProfileCatalog.linkedInURL

    struct Feedback {
        let message: String
        let success: Bool
        /// Se presente, o assistente fez uma pergunta e ficará ouvindo a resposta.
        let followUp: FollowUp?

        init(message: String, success: Bool, followUp: FollowUp? = nil) {
            self.message = message
            self.success = success
            self.followUp = followUp
        }
    }

    private let knowledgeService = KnowledgeService()
    private let settings: AppSettings
    private let panelViewModel: ClipboardPanelViewModel
    private let pasteService: PasteService
    private let screenshotService: ScreenshotService
    private let screenAnalysisService: ScreenAnalysisService
    private let targetApplicationProvider: () -> NSRunningApplication?
    private let openPanel: () -> Void
    private let closePanel: () -> Void
    private let openSettings: () -> Void
    private let hideOverlayForCapture: () -> Void

    init(
        settings: AppSettings,
        panelViewModel: ClipboardPanelViewModel,
        pasteService: PasteService,
        screenshotService: ScreenshotService,
        screenAnalysisService: ScreenAnalysisService,
        targetApplicationProvider: @escaping () -> NSRunningApplication?,
        openPanel: @escaping () -> Void,
        closePanel: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        hideOverlayForCapture: @escaping () -> Void
    ) {
        self.settings = settings
        self.panelViewModel = panelViewModel
        self.pasteService = pasteService
        self.screenshotService = screenshotService
        self.screenAnalysisService = screenAnalysisService
        self.targetApplicationProvider = targetApplicationProvider
        self.openPanel = openPanel
        self.closePanel = closePanel
        self.openSettings = openSettings
        self.hideOverlayForCapture = hideOverlayForCapture
    }

    func execute(rawText: String, completion: @escaping (Feedback) -> Void) {
        guard let command = VoiceCommandParser.parse(rawText) else {
            searchInternetAndSpeak(rawText, completion: completion)
            return
        }

        switch command {
        case .openApp(let name):
            let opened = openApplication(named: name)
            completion(Feedback(
                message: opened
                    ? t("Abrindo \(name)...", "Opening \(name)...")
                    : t("App \"\(name)\" não encontrado.", "App \"\(name)\" not found."),
                success: opened
            ))

        case .screenshotFull:
            screenshotService.capture(.fullScreen) { [weak self] success in
                guard let self else { return }
                completion(Feedback(
                    message: success
                        ? self.t("Print salvo no histórico.", "Screenshot saved to history.")
                        : self.t("Falha ao capturar a tela.", "Failed to capture the screen."),
                    success: success
                ))
            }

        case .screenshotArea:
            screenshotService.capture(.interactiveArea) { [weak self] success in
                guard let self else { return }
                completion(Feedback(
                    message: success
                        ? self.t("Captura salva no histórico.", "Capture saved to history.")
                        : self.t("Captura cancelada.", "Capture cancelled."),
                    success: success
                ))
            }

        case .analyzeScreen:
            let languageCode = settings.text(ptBR: "pt", en: "en")
            screenAnalysisService.describeVisibleScreen(
                languageCode: languageCode,
                onPrepareCapture: hideOverlayForCapture
            ) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let description):
                    completion(Feedback(message: description, success: true))
                case .failure(ScreenAnalysisError.permissionDenied):
                    completion(Feedback(
                        message: self.t(
                            "Preciso de permissão de Gravação de Tela. Ative em Ajustes do Sistema → Privacidade e Segurança → Gravação de Tela.",
                            "I need Screen Recording permission. Enable it in System Settings → Privacy & Security → Screen Recording."
                        ),
                        success: false
                    ))
                case .failure(ScreenAnalysisError.captureFailed):
                    completion(Feedback(
                        message: self.t("Não consegui capturar a tela.", "Failed to capture the screen."),
                        success: false
                    ))
                case .failure:
                    completion(Feedback(
                        message: self.t("Não consegui analisar a tela.", "Couldn't analyze the screen."),
                        success: false
                    ))
                }
            }

        case .openPanel:
            openPanel()
            completion(Feedback(message: t("Painel aberto.", "Panel opened."), success: true))

        case .closePanel:
            closePanel()
            completion(Feedback(message: t("Painel fechado.", "Panel closed."), success: true))

        case .copyItem(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            let copied = panelViewModel.copyToPasteboard(item: item)
            completion(Feedback(
                message: copied
                    ? t("Item \(index) copiado.", "Item \(index) copied.")
                    : t("Falha ao copiar o item \(index).", "Failed to copy item \(index)."),
                success: copied
            ))

        case .pasteItem(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            panelViewModel.paste(item: item, targetApplication: targetApplicationProvider())
            completion(Feedback(message: t("Colando item \(index)...", "Pasting item \(index)..."), success: true))

        case .pasteLast:
            panelViewModel.refresh()
            guard let item = panelViewModel.mostRecentItem() else {
                completion(Feedback(message: t("Histórico vazio.", "History is empty."), success: false))
                return
            }
            panelViewModel.paste(item: item, targetApplication: targetApplicationProvider())
            completion(Feedback(message: t("Colando último item...", "Pasting last item..."), success: true))

        case .readLastItem:
            panelViewModel.refresh()
            guard let item = panelViewModel.mostRecentItem() else {
                completion(Feedback(message: t("Histórico vazio.", "History is empty."), success: false))
                return
            }
            completion(Feedback(message: describeItem(item), success: true))

        case .copyLastItem:
            panelViewModel.refresh()
            guard let item = panelViewModel.mostRecentItem() else {
                completion(Feedback(message: t("Histórico vazio.", "History is empty."), success: false))
                return
            }
            let copied = panelViewModel.copyToPasteboard(item: item)
            completion(Feedback(
                message: copied
                    ? t("Último item copiado.", "Last item copied.")
                    : t("Falha ao copiar o último item.", "Failed to copy the last item."),
                success: copied
            ))

        case .favoriteItem(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            panelViewModel.toggleFavorite(itemID: item.id)
            completion(Feedback(message: t("Item \(index) favoritado.", "Item \(index) favorited."), success: true))

        case .deleteItem(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            panelViewModel.delete(itemID: item.id)
            completion(Feedback(message: t("Item \(index) apagado.", "Item \(index) deleted."), success: true))

        case .pinItem(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            panelViewModel.togglePin(itemID: item.id)
            let action = item.isPinned
                ? t("desafixado", "unpinned")
                : t("fixado", "pinned")
            completion(Feedback(message: t("Item \(index) \(action).", "Item \(index) \(action)."), success: true))

        case .historyCount:
            panelViewModel.refresh()
            let count = panelViewModel.itemCount
            let stack = panelViewModel.pasteStack.count
            let message = stack > 0
                ? t("\(count) itens no histórico e \(stack) na pilha.", "\(count) items in history and \(stack) in the stack.")
                : t("\(count) itens no histórico.", "\(count) items in history.")
            completion(Feedback(message: message, success: true))

        case .clearHistory:
            panelViewModel.clearAll()
            completion(Feedback(message: t("Histórico limpo.", "History cleared."), success: true))

        case .dictate(let text):
            pasteService.paste(text: text, targetApplication: targetApplicationProvider())
            completion(Feedback(message: t("Digitando...", "Typing..."), success: true))

        case .formatJSONLast:
            panelViewModel.refresh()
            let formatted = panelViewModel.formatMostRecentJSON()
            completion(Feedback(
                message: formatted
                    ? t("JSON formatado e copiado.", "JSON formatted and copied.")
                    : t("Último item não é um JSON válido.", "Last item is not valid JSON."),
                success: formatted
            ))

        case .transformLast(let transform):
            panelViewModel.refresh()
            let transformed = panelViewModel.transformMostRecent(transform)
            completion(Feedback(
                message: transformed
                    ? t("\(transform.title(for: settings.language)) aplicado e copiado.", "\(transform.title(for: settings.language)) applied and copied.")
                    : t("Não consegui aplicar essa transformação no último item.", "Couldn't apply that transform to the last item."),
                success: transformed
            ))

        case .saveSnippet(let name):
            panelViewModel.refresh()
            let saved = panelViewModel.saveMostRecentAsSnippet(named: name)
            completion(Feedback(
                message: saved
                    ? t("Snippet \"\(name)\" salvo.", "Snippet \"\(name)\" saved.")
                    : t("Nada para salvar como snippet.", "Nothing to save as a snippet."),
                success: saved
            ))

        case .pasteSnippet(let name):
            panelViewModel.refresh()
            guard let item = panelViewModel.snippet(named: name) else {
                completion(Feedback(
                    message: t("Snippet \"\(name)\" não encontrado.", "Snippet \"\(name)\" not found."),
                    success: false
                ))
                return
            }
            panelViewModel.paste(item: item, targetApplication: targetApplicationProvider())
            completion(Feedback(message: t("Colando snippet \"\(name)\"...", "Pasting snippet \"\(name)\"..."), success: true))

        case .listSnippets:
            panelViewModel.refresh()
            let names = panelViewModel.snippetNames()
            if names.isEmpty {
                completion(Feedback(message: t("Você ainda não tem snippets salvos.", "You don't have any saved snippets yet."), success: false))
            } else {
                let list = names.joined(separator: ", ")
                completion(Feedback(message: t("Seus snippets: \(list).", "Your snippets: \(list)."), success: true))
            }

        case .stackAdd(let index):
            panelViewModel.refresh()
            guard let item = panelViewModel.item(atDisplayIndex: index) else {
                completion(itemNotFoundFeedback(index))
                return
            }
            panelViewModel.addToStack(itemID: item.id)
            completion(Feedback(
                message: t("Item \(index) na pilha (\(panelViewModel.pasteStack.count)).", "Item \(index) stacked (\(panelViewModel.pasteStack.count))."),
                success: true
            ))

        case .stackPasteNext:
            let pasted = panelViewModel.pasteNextFromStack(targetApplication: targetApplicationProvider())
            completion(Feedback(
                message: pasted
                    ? t("Colando próximo da pilha (\(panelViewModel.pasteStack.count) restantes).", "Pasting next from stack (\(panelViewModel.pasteStack.count) left).")
                    : t("Pilha vazia.", "Stack is empty."),
                success: pasted
            ))

        case .stackClear:
            panelViewModel.clearStack()
            completion(Feedback(message: t("Pilha limpa.", "Stack cleared."), success: true))

        case .pauseMonitoring:
            settings.pauseMonitoring = true
            completion(Feedback(message: t("Monitoramento pausado.", "Monitoring paused."), success: true))

        case .resumeMonitoring:
            settings.pauseMonitoring = false
            completion(Feedback(message: t("Monitoramento retomado.", "Monitoring resumed."), success: true))

        case .currentTime:
            let formatter = DateFormatter()
            formatter.locale = currentLocale()
            formatter.timeStyle = .short
            let time = formatter.string(from: Date())
            completion(Feedback(message: t("Agora são \(time).", "It's \(time) right now."), success: true))

        case .currentDate:
            let formatter = DateFormatter()
            formatter.locale = currentLocale()
            formatter.dateStyle = .full
            let date = formatter.string(from: Date())
            completion(Feedback(message: t("Hoje é \(date).", "Today is \(date)."), success: true))

        case .dayOfWeek:
            let formatter = DateFormatter()
            formatter.locale = currentLocale()
            formatter.dateFormat = "EEEE"
            let day = formatter.string(from: Date())
            completion(Feedback(message: t("Hoje é \(day).", "Today is \(day)."), success: true))

        case .weather:
            fetchWeather(completion: completion)

        case .openWebsite(let site):
            if let url = websiteURL(from: site) {
                NSWorkspace.shared.open(url)
                completion(Feedback(message: t("Abrindo \(url.host ?? site)...", "Opening \(url.host ?? site)..."), success: true))
            } else {
                completion(Feedback(
                    message: t("Não consegui montar o endereço \"\(site)\".", "Couldn't build the address \"\(site)\"."),
                    success: false
                ))
            }

        case .setUserName(let name):
            settings.userName = name
            completion(Feedback(
                message: t("Prazer, \(name)! Vou lembrar do seu nome.", "Nice to meet you, \(name)! I'll remember your name."),
                success: true
            ))

        case .askUserName:
            if settings.userName.isEmpty {
                completion(Feedback(
                    message: t(
                        "Ainda não sei seu nome. Diga: \"meu nome é ...\" que eu guardo.",
                        "I don't know your name yet. Say \"my name is ...\" and I'll remember it."
                    ),
                    success: false
                ))
            } else {
                completion(Feedback(
                    message: t("Você é o \(settings.userName)!", "You're \(settings.userName)!"),
                    success: true
                ))
            }

        case .aboutAssistant:
            let greeting = settings.userName.isEmpty
                ? ""
                : settings.text(ptBR: "Oi, \(settings.userName)! ", en: "Hi, \(settings.userName)! ")
            completion(Feedback(
                message: greeting + t(
                    "Eu sou o Clip, o assistente de voz do ClipFlow — um gerenciador de área de transferência nativo para macOS. Eu abro apps e sites, tiro prints, colo itens do seu histórico, respondo perguntas, digo as horas e o clima. É só pedir!",
                    "I'm Clip, ClipFlow's voice assistant — a native clipboard manager for macOS. I open apps and websites, take screenshots, paste items from your history, answer questions, and tell you the time and weather. Just ask!"
                ),
                success: true
            ))

        case .aboutDeveloper:
            completion(Feedback(
                message: t(
                    "Fui desenvolvido pelo \(Self.developerName). Quer que eu abra o LinkedIn dele?",
                    "I was built by \(Self.developerName). Want me to open his LinkedIn?"
                ),
                success: true,
                followUp: .openURL(Self.developerLinkedInURL)
            ))

        case .openDeveloperProfile:
            if let url = URL(string: Self.developerLinkedInURL) {
                NSWorkspace.shared.open(url)
            }
            completion(Feedback(
                message: t("Abrindo o LinkedIn do \(Self.developerName)...", "Opening \(Self.developerName)'s LinkedIn..."),
                success: true
            ))

        case .help:
            completion(Feedback(
                message: VoiceCommandCatalog.helpMessage(pt: usesPortuguese),
                success: true
            ))

        case .greeting(let kind):
            completion(Feedback(message: greetingMessage(for: kind), success: true))

        case .thanks:
            completion(Feedback(
                message: t("Por nada! Estou aqui se precisar.", "You're welcome! I'm here if you need me."),
                success: true
            ))

        case .goodbye:
            completion(Feedback(
                message: t("Até logo! Chame o Clip quando quiser.", "See you! Call Clip anytime."),
                success: true
            ))

        case .howAreYou:
            completion(Feedback(
                message: t("Estou ótimo e pronto para ajudar!", "I'm great and ready to help!"),
                success: true
            ))

        case .openSettings:
            openSettings()
            completion(Feedback(message: t("Abrindo configurações...", "Opening settings..."), success: true))

        case .setVoiceEnabled(let enabled):
            settings.voiceControlEnabled = enabled
            completion(Feedback(
                message: enabled
                    ? t("Comandos de voz ativados.", "Voice commands enabled.")
                    : t("Comandos de voz desativados.", "Voice commands disabled."),
                success: true
            ))

        case .lockScreen:
            runShellCommand("/usr/bin/pmset", arguments: ["displaysleepnow"])
            completion(Feedback(message: t("Tela bloqueada.", "Screen locked."), success: true))

        case .openSpotlight:
            runAppleScript("tell application \"System Events\" to keystroke space using command down")
            completion(Feedback(message: t("Abrindo Spotlight...", "Opening Spotlight..."), success: true))

        case .volumeAdjust(let action):
            adjustVolume(action)
            let message: String
            switch action {
            case .up: message = t("Volume aumentado.", "Volume increased.")
            case .down: message = t("Volume diminuído.", "Volume decreased.")
            case .mute: message = t("Som silenciado.", "Sound muted.")
            }
            completion(Feedback(message: message, success: true))

        case .openFolder(let folder):
            NSWorkspace.shared.open(folder.url)
            completion(Feedback(
                message: t("Abrindo \(folder.spokenName(pt: usesPortuguese))...", "Opening \(folder.spokenName(pt: usesPortuguese))..."),
                success: true
            ))

        case .searchHistory(let query):
            panelViewModel.searchText = query
            panelViewModel.setFilter(.all)
            openPanel()
            completion(Feedback(
                message: t("Buscando \"\(query)\" no histórico...", "Searching history for \"\(query)\"..."),
                success: true
            ))

        case .showFilter(let filter):
            panelViewModel.setFilter(filter)
            openPanel()
            completion(Feedback(
                message: t("Mostrando \(filter.title(for: settings.language)).", "Showing \(filter.title(for: settings.language))."),
                success: true
            ))

        case .calculate(let result):
            completion(Feedback(
                message: t("O resultado é \(result).", "The result is \(result)."),
                success: true
            ))

        case .question(let question):
            answerQuestion(question, completion: completion)

        case .webSearch(let query):
            completion(performWebSearch(query))
        }
    }

    /// Trata a resposta falada a uma pergunta do assistente
    /// (ex.: "Quer que eu pesquise na web?" -> "sim").
    func handleFollowUpResponse(_ followUp: FollowUp, answer: String, completion: @escaping (Feedback) -> Void) {
        let normalized = VoiceCommandParser.normalize(answer)
        let words = Set(normalized.split(separator: " ").map(String.init))

        let negatives: Set<String> = ["nao", "nope", "cancela", "deixa", "esquece"]
        let affirmatives: Set<String> = ["sim", "pode", "claro", "quero", "manda", "vai", "bora", "yes", "sure", "yep", "ok", "please"]

        if !words.isDisjoint(with: negatives) || normalized == "no" {
            completion(Feedback(message: t("Ok, deixei pra lá.", "Okay, never mind."), success: true))
            return
        }

        if !words.isDisjoint(with: affirmatives) {
            switch followUp {
            case .webSearch(let query):
                searchInternetAndSpeak(query, completion: completion)
            case .openURL(let urlString):
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                    completion(Feedback(message: t("Abrindo...", "Opening..."), success: true))
                } else {
                    completion(Feedback(message: t("Não consegui abrir o link.", "Couldn't open the link."), success: false))
                }
            }
            return
        }

        // Não foi sim/não: trata como um novo comando normal.
        execute(rawText: answer, completion: completion)
    }

    private func performWebSearch(_ query: String) -> Feedback {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components?.url else {
            return Feedback(message: t("Não consegui pesquisar isso.", "Couldn't run that search."), success: false)
        }
        NSWorkspace.shared.open(url)
        return Feedback(message: t("Pesquisando por \"\(query)\"...", "Searching for \"\(query)\"..."), success: true)
    }

    // MARK: - Assistente

    private func answerQuestion(_ question: String, completion: @escaping (Feedback) -> Void) {
        let normalized = VoiceCommandParser.normalize(question)
        if let assistantIntent = AssistantIntentDetector.detect(normalized: normalized) {
            completion(localAssistantFeedback(for: assistantIntent))
            return
        }

        if let developerFeedback = developerKnowledgeFeedback(for: question) {
            completion(developerFeedback)
            return
        }

        let languageCode = settings.text(ptBR: "pt", en: "en")
        let prepared = QuestionPreprocessor.prepare(question) ?? question
        knowledgeService.answer(question: prepared, languageCode: languageCode) { [weak self] answer in
            guard let self else { return }
            if let answer, KnowledgeService.isAnswerRelevant(answer, to: prepared) {
                completion(Feedback(message: answer, success: true))
            } else {
                self.searchInternetAndSpeak(
                    prepared,
                    completion: completion
                )
            }
        }
    }

    private func localAssistantFeedback(for intent: AssistantIntent) -> Feedback {
        switch intent {
        case .aboutAssistant:
            let greeting = settings.userName.isEmpty
                ? ""
                : settings.text(ptBR: "Oi, \(settings.userName)! ", en: "Hi, \(settings.userName)! ")
            return Feedback(
                message: greeting + t(
                    "Eu sou o Clip, o assistente de voz do ClipFlow — um gerenciador de área de transferência nativo para macOS. Eu abro apps e sites, tiro prints, colo itens do seu histórico, respondo perguntas, digo as horas e o clima. É só pedir!",
                    "I'm Clip, ClipFlow's voice assistant — a native clipboard manager for macOS. I open apps and websites, take screenshots, paste items from your history, answer questions, and tell you the time and weather. Just ask!"
                ),
                success: true
            )
        case .aboutDeveloper:
            return Feedback(
                message: t(
                    "Fui desenvolvido pelo \(Self.developerName). Quer que eu abra o LinkedIn dele?",
                    "I was built by \(Self.developerName). Want me to open his LinkedIn?"
                ),
                success: true,
                followUp: .openURL(Self.developerLinkedInURL)
            )
        case .openDeveloperProfile:
            if let url = URL(string: Self.developerLinkedInURL) {
                NSWorkspace.shared.open(url)
            }
            return Feedback(
                message: t("Abrindo o LinkedIn do \(Self.developerName)...", "Opening \(Self.developerName)'s LinkedIn..."),
                success: true
            )
        case .help:
            return Feedback(
                message: VoiceCommandCatalog.helpMessage(pt: usesPortuguese),
                success: true
            )
        }
    }

    private func developerKnowledgeFeedback(for question: String) -> Feedback? {
        guard let answer = DeveloperKnowledgeService.answer(question: question, portuguese: usesPortuguese) else {
            return nil
        }

        let followUp: FollowUp?
        switch answer.followUp {
        case .searchWeb(let query):
            followUp = .webSearch(query)
        case .openLinkedIn:
            followUp = .openURL(DeveloperProfileCatalog.linkedInURL)
        case nil:
            followUp = nil
        }

        return Feedback(message: answer.message, success: true, followUp: followUp)
    }

    /// Pesquisa na internet e fala o que encontrou quando o comando não foi reconhecido.
    private func searchInternetAndSpeak(
        _ rawText: String,
        completion: @escaping (Feedback) -> Void
    ) {
        let normalized = VoiceCommandParser.normalize(rawText)
        if let assistantIntent = AssistantIntentDetector.detect(normalized: normalized) {
            completion(localAssistantFeedback(for: assistantIntent))
            return
        }

        if let developerFeedback = developerKnowledgeFeedback(for: rawText) {
            completion(developerFeedback)
            return
        }

        guard let query = KnowledgeService.resolveSearchQuery(from: rawText) else {
            completion(Feedback(
                message: t("Não entendi.", "I didn't understand."),
                success: false
            ))
            return
        }

        let languageCode = settings.text(ptBR: "pt", en: "en")
        knowledgeService.searchInternetForSpeech(
            query: query,
            languageCode: languageCode
        ) { [weak self] answer in
            guard let self else { return }
            if let answer, KnowledgeService.isAnswerRelevant(answer, to: query) {
                completion(Feedback(message: answer, success: true))
            } else {
                completion(Feedback(
                    message: self.t(
                        "Pesquisei na internet sobre \"\(query)\" mas não encontrei uma resposta clara.",
                        "I searched the internet for \"\(query)\" but couldn't find a clear answer."
                    ),
                    success: false
                ))
            }
        }
    }

    private func currentLocale() -> Locale {
        Locale(identifier: settings.text(ptBR: "pt_BR", en: "en_US"))
    }

    private func websiteURL(from site: String) -> URL? {
        var address = site.replacingOccurrences(of: " ", with: "")
        guard !address.isEmpty else { return nil }

        if !address.contains("://") {
            address = "https://" + address
        }
        if !address.contains(".") {
            address += ".com"
        }

        guard let url = URL(string: address), url.host != nil else { return nil }
        return url
    }

    /// Clima atual via wttr.in (gratuito, sem chave; localização por IP).
    private func fetchWeather(completion: @escaping (Feedback) -> Void) {
        let lang = settings.text(ptBR: "pt", en: "en")
        guard let url = URL(string: "https://wttr.in/?format=%t|%C&lang=\(lang)") else {
            completion(Feedback(message: t("Não consegui consultar o tempo.", "Couldn't check the weather."), success: false))
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6

        let failureMessage = t(
            "Não consegui consultar o tempo agora. Verifique a conexão.",
            "Couldn't check the weather right now. Check your connection."
        )

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard error == nil,
                      let data,
                      let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty, text.count < 80 else {
                    completion(Feedback(message: failureMessage, success: false))
                    return
                }

                let parts = text.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                let temperature = parts.first ?? text
                let condition = parts.count > 1 ? parts[1].lowercased() : nil

                let message: String
                if let condition {
                    message = self.t("Agora faz \(temperature), com \(condition).", "It's \(temperature) right now, \(condition).")
                } else {
                    message = self.t("Agora faz \(temperature).", "It's \(temperature) right now.")
                }
                completion(Feedback(message: message, success: true))
            }
        }
        task.resume()
    }

    // MARK: - Helpers

    private func itemNotFoundFeedback(_ index: Int) -> Feedback {
        Feedback(
            message: t("Item \(index) não existe no histórico.", "Item \(index) doesn't exist in history."),
            success: false
        )
    }

    private func openApplication(named name: String) -> Bool {
        if let url = resolveApplicationURL(named: name) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return true
        }
        return false
    }

    private func resolveApplicationURL(named name: String) -> URL? {
        let query = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        let fileManager = FileManager.default
        let directories = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            (fileManager.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("Applications")
        ]

        var exactMatch: URL?
        var prefixMatch: URL?
        var containsMatch: URL?

        for directory in directories {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            for entry in contents where entry.hasSuffix(".app") {
                let appName = (entry as NSString).deletingPathExtension.lowercased()
                let url = URL(fileURLWithPath: directory).appendingPathComponent(entry)

                if appName == query {
                    exactMatch = url
                } else if exactMatch == nil, prefixMatch == nil, appName.hasPrefix(query) {
                    prefixMatch = url
                } else if exactMatch == nil, prefixMatch == nil, containsMatch == nil, appName.contains(query) {
                    containsMatch = url
                }
            }
            if exactMatch != nil { break }
        }

        return exactMatch ?? prefixMatch ?? containsMatch
    }

    private func t(_ pt: String, _ en: String) -> String {
        settings.text(ptBR: pt, en: en)
    }

    private var usesPortuguese: Bool {
        switch settings.language {
        case .portuguese: return true
        case .english: return false
        case .system:
            return Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") == true
        }
    }

    private func describeItem(_ item: DecodedClipboardItem) -> String {
        switch item.kind {
        case .text:
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return t("O último item é um texto vazio.", "The last item is empty text.")
            }
            let maxLength = 400
            if text.count <= maxLength {
                return t("Você copiou: \(text)", "You copied: \(text)")
            }
            let prefix = String(text.prefix(maxLength))
            return t("Você copiou: \(prefix)...", "You copied: \(prefix)...")
        case .image:
            return t("O último item é uma imagem.", "The last item is an image.")
        }
    }

    private func greetingMessage(for kind: GreetingKind) -> String {
        let name = settings.userName.isEmpty ? "" : ", \(settings.userName)"
        switch kind {
        case .morning:
            return t("Bom dia\(name)! Como posso ajudar?", "Good morning\(name)! How can I help?")
        case .afternoon:
            return t("Boa tarde\(name)! Como posso ajudar?", "Good afternoon\(name)! How can I help?")
        case .evening:
            return t("Boa noite\(name)! Como posso ajudar?", "Good evening\(name)! How can I help?")
        case .generic:
            return t("Olá\(name)! O que você precisa?", "Hello\(name)! What do you need?")
        }
    }

    private func runShellCommand(_ path: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        try? process.run()
    }

    private func runAppleScript(_ script: String) {
        runShellCommand("/usr/bin/osascript", arguments: ["-e", script])
    }

    private func adjustVolume(_ action: VolumeAction) {
        let script: String
        switch action {
        case .up:
            script = "set volume output volume ((output volume of (get volume settings)) + 10)"
        case .down:
            script = "set volume output volume ((output volume of (get volume settings)) - 10)"
        case .mute:
            script = "set volume with output muted"
        }
        runAppleScript(script)
    }
}
