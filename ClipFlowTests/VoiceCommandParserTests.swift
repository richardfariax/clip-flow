import XCTest
@testable import ClipFlow

final class VoiceCommandParserTests: XCTestCase {
    func testOpenApp() {
        XCTAssertEqual(VoiceCommandParser.parse("abra o Xcode"), .openApp("Xcode"))
        XCTAssertEqual(VoiceCommandParser.parse("abrir Safari"), .openApp("Safari"))
        XCTAssertEqual(VoiceCommandParser.parse("open the Terminal"), .openApp("Terminal"))
    }

    func testScreenshot() {
        XCTAssertEqual(VoiceCommandParser.parse("tire um print"), .screenshotFull)
        XCTAssertEqual(VoiceCommandParser.parse("tire um print da área"), .screenshotArea)
        XCTAssertEqual(VoiceCommandParser.parse("take a screenshot"), .screenshotFull)
    }

    func testAnalyzeScreen() {
        XCTAssertEqual(VoiceCommandParser.parse("veja o que está na tela"), .analyzeScreen)
        XCTAssertEqual(VoiceCommandParser.parse("analise o que tem na tela"), .analyzeScreen)
        XCTAssertEqual(VoiceCommandParser.parse("o que tem na tela"), .analyzeScreen)
        XCTAssertEqual(VoiceCommandParser.parse("leia a tela"), .analyzeScreen)
        XCTAssertEqual(VoiceCommandParser.parse("what's on the screen"), .analyzeScreen)
    }

    func testPanel() {
        XCTAssertEqual(VoiceCommandParser.parse("abra o painel"), .openPanel)
        XCTAssertEqual(VoiceCommandParser.parse("feche o painel"), .closePanel)
    }

    func testClipboardItems() {
        XCTAssertEqual(VoiceCommandParser.parse("copie o item 2"), .copyItem(2))
        XCTAssertEqual(VoiceCommandParser.parse("cole o item três"), .pasteItem(3))
        XCTAssertEqual(VoiceCommandParser.parse("cole o último"), .pasteLast)
        XCTAssertEqual(VoiceCommandParser.parse("favorite o item 1"), .favoriteItem(1))
        XCTAssertEqual(VoiceCommandParser.parse("limpar histórico"), .clearHistory)
    }

    func testDictate() {
        XCTAssertEqual(VoiceCommandParser.parse("digite bom dia equipe"), .dictate("bom dia equipe"))
    }

    func testSnippets() {
        XCTAssertEqual(VoiceCommandParser.parse("salve como deploy"), .saveSnippet("deploy"))
        XCTAssertEqual(VoiceCommandParser.parse("cole o snippet deploy"), .pasteSnippet("deploy"))
    }

    func testStack() {
        XCTAssertEqual(VoiceCommandParser.parse("adicione o item 2 à pilha"), .stackAdd(2))
        XCTAssertEqual(VoiceCommandParser.parse("cole a pilha"), .stackPasteNext)
        XCTAssertEqual(VoiceCommandParser.parse("limpar pilha"), .stackClear)
    }

    func testMonitoringAndJSON() {
        XCTAssertEqual(VoiceCommandParser.parse("pausar monitoramento"), .pauseMonitoring)
        XCTAssertEqual(VoiceCommandParser.parse("retomar monitoramento"), .resumeMonitoring)
        XCTAssertEqual(VoiceCommandParser.parse("formate o json"), .formatJSONLast)
    }

    func testAssistantCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("que horas são"), .currentTime)
        XCTAssertEqual(VoiceCommandParser.parse("que dia é hoje"), .currentDate)
        XCTAssertEqual(VoiceCommandParser.parse("quantos graus agora"), .weather)
        XCTAssertEqual(VoiceCommandParser.parse("como está o tempo"), .weather)
        XCTAssertEqual(VoiceCommandParser.parse("abra o site github.com"), .openWebsite("github.com"))
        XCTAssertEqual(VoiceCommandParser.parse("abra github ponto com"), .openWebsite("github.com"))
        XCTAssertEqual(VoiceCommandParser.parse("pesquise swift concurrency"), .webSearch("swift concurrency"))
    }

    func testUserName() {
        XCTAssertEqual(VoiceCommandParser.parse("meu nome é Richard"), .setUserName("Richard"))
        XCTAssertEqual(VoiceCommandParser.parse("qual é o meu nome"), .askUserName)
    }

    func testQuestionFallback() {
        XCTAssertEqual(VoiceCommandParser.parse("quem é o presidente do Brasil"), .question("quem é o presidente do Brasil"))
        XCTAssertEqual(VoiceCommandParser.parse("o que é fotossíntese"), .question("o que é fotossíntese"))
        XCTAssertEqual(VoiceCommandParser.parse("qual a capital do Brasil"), .question("qual a capital do Brasil"))
        XCTAssertEqual(VoiceCommandParser.parse("sabe me dizer quem inventou o avião"), .question("quem inventou o avião"))
        XCTAssertEqual(VoiceCommandParser.parse("me explica fotossíntese"), .question("me explica fotossíntese"))
        XCTAssertEqual(VoiceCommandParser.parse("capital do brasil"), .question("capital do brasil"))
    }

    func testQuestionPreprocessor() {
        XCTAssertEqual(QuestionPreprocessor.prepare("clipe quem é o presidente do brasil"), "quem é o presidente do brasil")
        XCTAssertEqual(QuestionPreprocessor.prepare("eu quero saber qual a capital do brasil"), "qual a capital do brasil")
        XCTAssertNil(QuestionPreprocessor.prepare("bom dia"))
    }

    func testKnowledgeSearchTerms() {
        XCTAssertEqual(KnowledgeService.searchTerms(from: "quem é o presidente do Brasil"), "presidente do brasil")
        XCTAssertEqual(KnowledgeService.searchTerms(from: "qual presidente do Brasil"), "presidente do brasil")
        XCTAssertEqual(KnowledgeService.searchTerms(from: "o que é fotossíntese?"), "fotossintese")
    }

    func testKnowledgeAnalysis() {
        let who = KnowledgeService.analyze(question: "quem é o presidente do Brasil")
        XCTAssertEqual(who.intent, .who)
        XCTAssertTrue(who.searchQueries.contains("presidente do brasil atual"))

        let qual = KnowledgeService.analyze(question: "qual presidente do Brasil")
        XCTAssertEqual(qual.intent, .who)

        let what = KnowledgeService.analyze(question: "o que é fotossíntese")
        XCTAssertEqual(what.intent, .what)

        let capital = KnowledgeService.analyze(question: "qual a capital do brasil")
        XCTAssertEqual(capital.intent, .whereLocation)
    }

    func testKnowledgeScoring() {
        let analysis = KnowledgeService.analyze(question: "quem é o presidente do Brasil")
        let good = KnowledgeService.scoreAnswer(
            "O presidente do Brasil é Luiz Inácio Lula da Silva.",
            analysis: analysis
        )
        let bad = KnowledgeService.scoreAnswer(
            "Lista de presidentes do Brasil ao longo da história.",
            analysis: analysis
        )
        XCTAssertGreaterThan(good, bad)
    }

    func testKnowledgeAnswerFormatting() {
        let text = "Luiz Inácio Lula da Silva é o atual presidente do Brasil desde 2023. Ele foi eleito em outubro de 2022."
        let answer = KnowledgeService.formatAnswer(
            from: text,
            question: "quem é o presidente do Brasil",
            intent: .who,
            languageCode: "pt"
        )
        XCTAssertTrue(answer.lowercased().contains("lula") || answer.lowercased().contains("atual"))
    }

    func testAssistantIdentity() {
        XCTAssertEqual(VoiceCommandParser.parse("quem é você"), .aboutAssistant)
        XCTAssertEqual(VoiceCommandParser.parse("quem desenvolveu você"), .aboutDeveloper)
        XCTAssertEqual(VoiceCommandParser.parse("quem te criou"), .aboutDeveloper)
        XCTAssertEqual(VoiceCommandParser.parse("você foi desenvolvido por quem"), .aboutDeveloper)
        XCTAssertEqual(VoiceCommandParser.parse("por quem você foi criado"), .aboutDeveloper)
        XCTAssertEqual(VoiceCommandParser.parse("quem é o seu desenvolvedor"), .aboutDeveloper)
        XCTAssertEqual(VoiceCommandParser.parse("abra o linkedin do dono"), .openDeveloperProfile)
        XCTAssertEqual(VoiceCommandParser.parse("abra o linkedin"), .openWebsite("linkedin.com"))
        XCTAssertEqual(VoiceCommandParser.parse("o que você sabe fazer"), .help)
    }

    func testAssistantIntentDetector() {
        XCTAssertEqual(
            AssistantIntentDetector.detect(normalized: "voce foi desenvolvido por quem"),
            .aboutDeveloper
        )
        XCTAssertNil(QuestionPreprocessor.prepare("você foi desenvolvido por quem"))
    }

    func testAnswerRelevance() {
        let relevant = KnowledgeService.isAnswerRelevant(
            "A fotossíntese é o processo pelo qual plantas convertem luz em energia.",
            to: "o que é fotossíntese"
        )
        let irrelevant = KnowledgeService.isAnswerRelevant(
            "Lista de presidentes do Brasil ao longo da história.",
            to: "o que é fotossíntese"
        )
        XCTAssertTrue(relevant)
        XCTAssertFalse(irrelevant)
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(VoiceCommandParser.parse(""))
    }

    func testGreeting() {
        XCTAssertEqual(VoiceCommandParser.parse("bom dia"), .greeting(.morning))
        XCTAssertEqual(VoiceCommandParser.parse("boa tarde"), .greeting(.afternoon))
        XCTAssertEqual(VoiceCommandParser.parse("oi"), .greeting(.generic))
    }

    func testSocialCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("obrigado"), .thanks)
        XCTAssertEqual(VoiceCommandParser.parse("tchau"), .goodbye)
        XCTAssertEqual(VoiceCommandParser.parse("como você está"), .howAreYou)
    }

    func testMath() {
        XCTAssertEqual(VoiceCommandParser.parse("quanto é 15 mais 7"), .calculate("22"))
        XCTAssertEqual(VoiceCommandParser.parse("calcule 10 vezes 3"), .calculate("30"))
    }

    func testExtendedClipboardCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("o que eu copiei"), .readLastItem)
        XCTAssertEqual(VoiceCommandParser.parse("copie o último"), .copyLastItem)
        XCTAssertEqual(VoiceCommandParser.parse("quantos itens no histórico"), .historyCount)
        XCTAssertEqual(VoiceCommandParser.parse("apague o item 2"), .deleteItem(2))
        XCTAssertEqual(VoiceCommandParser.parse("fixe o item 1"), .pinItem(1))
        XCTAssertEqual(VoiceCommandParser.parse("busque no histórico deploy"), .searchHistory("deploy"))
    }

    func testTextTransforms() {
        XCTAssertEqual(VoiceCommandParser.parse("minifique o json"), .transformLast(.minifyJSON))
        XCTAssertEqual(VoiceCommandParser.parse("em maiúsculas"), .transformLast(.upperCase))
        XCTAssertEqual(VoiceCommandParser.parse("codificar base64"), .transformLast(.base64Encode))
    }

    func testSystemCommands() {
        XCTAssertEqual(VoiceCommandParser.parse("abra as configurações"), .openSettings)
        XCTAssertEqual(VoiceCommandParser.parse("bloqueie a tela"), .lockScreen)
        XCTAssertEqual(VoiceCommandParser.parse("abra o spotlight"), .openSpotlight)
        XCTAssertEqual(VoiceCommandParser.parse("aumente o volume"), .volumeAdjust(.up))
        XCTAssertEqual(VoiceCommandParser.parse("abra downloads"), .openFolder(.downloads))
        XCTAssertEqual(VoiceCommandParser.parse("mostre favoritos"), .showFilter(.favorites))
        XCTAssertEqual(VoiceCommandParser.parse("liste os snippets"), .listSnippets)
        XCTAssertEqual(VoiceCommandParser.parse("que dia da semana é hoje"), .dayOfWeek)
    }

    func testWebsiteAliases() {
        XCTAssertEqual(VoiceCommandParser.parse("abra o youtube"), .openWebsite("youtube.com"))
        XCTAssertEqual(VoiceCommandParser.parse("abra o gmail"), .openWebsite("gmail.com"))
    }

    func testVoiceControlToggle() {
        XCTAssertEqual(VoiceCommandParser.parse("ative comandos de voz"), .setVoiceEnabled(true))
        XCTAssertEqual(VoiceCommandParser.parse("desative comandos de voz"), .setVoiceEnabled(false))
    }

    func testSearchQueryFromUnknownSpeech() {
        XCTAssertEqual(
            KnowledgeService.searchQuery(from: "quem inventou o avião"),
            "quem inventou o avião"
        )
        XCTAssertNil(KnowledgeService.searchQuery(from: "bom dia"))
    }

    func testResolveSearchQueryFallback() {
        XCTAssertEqual(
            KnowledgeService.resolveSearchQuery(from: "clipe fotossíntese"),
            "fotossíntese"
        )
        XCTAssertEqual(
            KnowledgeService.resolveSearchQuery(from: "inteligência artificial"),
            "inteligência artificial"
        )
        XCTAssertEqual(
            KnowledgeService.resolveSearchQuery(from: "quem inventou o avião"),
            "quem inventou o avião"
        )
        XCTAssertNil(KnowledgeService.resolveSearchQuery(from: "obrigado"))
        XCTAssertNil(KnowledgeService.resolveSearchQuery(from: ""))
    }
}
