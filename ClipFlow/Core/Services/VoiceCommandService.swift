import AVFoundation
import Foundation
import Speech

/// Escuta contínua do microfone usando Speech nativo (SFSpeechRecognizer, on-device
/// quando disponível). Detecta a wake word (ex.: "Clipe") e captura o comando falado
/// após ela, finalizando por pausa de fala.
@MainActor
final class VoiceCommandService: ObservableObject {
    enum ListeningState: Equatable {
        case disabled
        case listening
        case capturingCommand
        case unavailable(String)
    }

    @Published private(set) var state: ListeningState = .disabled
    @Published private(set) var capturedTranscript: String = ""

    /// Chamado quando a wake word é detectada (para exibir o HUD).
    var onWakeWordDetected: (() -> Void)?
    /// Transcript parcial do comando (para HUD ao vivo).
    var onPartialCommand: ((String) -> Void)?
    /// Comando finalizado (texto cru após a wake word).
    var onCommandCaptured: ((String) -> Void)?
    /// Nenhum comando falado dentro da janela após a wake word.
    var onCaptureCancelled: (() -> Void)?

    private let settings: AppSettings

    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private var silenceTimer: Timer?
    private var sessionRestartTimer: Timer?
    private var commandTimeoutTimer: Timer?
    private var isEngineRunning = false
    private var commandStartOffset: Int?
    /// Verdadeiro entre a wake word e a finalização/timeout do comando.
    /// Sobrevive a reinícios de sessão de reconhecimento.
    private var isAwaitingCommand = false
    /// Sessão iniciada por atalho (push-to-talk): o microfone desliga ao terminar.
    private var isManualSession = false
    /// Identifica a sessão atual; callbacks de sessões canceladas são ignorados
    /// (cancelar uma task gera um callback de erro que causava loop de reinícios).
    private var sessionGeneration = 0
    private var isRestartScheduled = false
    /// Microfone pausado enquanto o assistente fala (evita auto-captura da própria voz).
    private var isPausedForSpeechOutput = false
    private var wasListeningBeforeSpeechPause = false

    private let silenceInterval: TimeInterval = 1.2
    private let commandTimeoutInterval: TimeInterval = 8
    private let sessionRestartInterval: TimeInterval = 50

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start() {
        guard state == .disabled || isUnavailable else { return }

        Task {
            let speechGranted = await Self.requestSpeechAuthorization()
            let micGranted = await Self.requestMicrophoneAuthorization()

            guard speechGranted, micGranted else {
                self.state = .unavailable(
                    self.settings.text(
                        ptBR: "Permissão de microfone ou reconhecimento de fala negada.",
                        en: "Microphone or speech recognition permission denied."
                    )
                )
                return
            }

            self.startRecognitionSession()
        }
    }

    func stop() {
        cancelCommandTimeout()
        isAwaitingCommand = false
        isManualSession = false
        isPausedForSpeechOutput = false
        wasListeningBeforeSpeechPause = false
        tearDownRecognition()
        stopAudioEngine()
        state = .disabled
    }

    /// Suspende microfone e reconhecimento enquanto o Clip fala a resposta.
    func pauseForSpeechOutput() {
        guard !isPausedForSpeechOutput else { return }

        isPausedForSpeechOutput = true
        wasListeningBeforeSpeechPause = settings.voiceActivationMode == .wakeWord
            && !isManualSession
            && state != .disabled
            && !isUnavailable

        isRestartScheduled = false
        cancelCommandTimeout()
        isAwaitingCommand = false
        commandStartOffset = nil
        capturedTranscript = ""
        tearDownRecognition()
        stopAudioEngine()
    }

    /// Retoma a escuta contínua (wake word) após a resposta falada terminar.
    func resumeAfterSpeechOutput() {
        guard isPausedForSpeechOutput else { return }

        isPausedForSpeechOutput = false
        let shouldResume = wasListeningBeforeSpeechPause
        wasListeningBeforeSpeechPause = false

        guard shouldResume, settings.voiceActivationMode == .wakeWord else { return }
        startRecognitionSession()
    }

    /// Ouve a resposta a uma pergunta do assistente, sem exigir wake word.
    /// Em modo contínuo reinicia a sessão em modo captura; em modo atalho
    /// liga o microfone só para a resposta.
    func beginFollowUpCapture() {
        isPausedForSpeechOutput = false
        wasListeningBeforeSpeechPause = false

        if state == .disabled || isUnavailable {
            beginManualCapture()
            return
        }

        guard state == .listening else { return }
        isAwaitingCommand = true
        startRecognitionSession()
        guard state == .capturingCommand else { return }
        startCommandTimeout()
        onWakeWordDetected?()
    }

    /// Push-to-talk: liga o microfone apenas para capturar um comando.
    /// Ao finalizar (ou expirar), o microfone é desligado por completo.
    func beginManualCapture() {
        guard state == .disabled || isUnavailable else { return }

        Task {
            let speechGranted = await Self.requestSpeechAuthorization()
            let micGranted = await Self.requestMicrophoneAuthorization()

            guard speechGranted, micGranted else {
                self.state = .unavailable(
                    self.settings.text(
                        ptBR: "Permissão de microfone ou reconhecimento de fala negada.",
                        en: "Microphone or speech recognition permission denied."
                    )
                )
                return
            }

            self.isManualSession = true
            self.isAwaitingCommand = true
            self.startRecognitionSession()
            guard self.state == .capturingCommand else { return }
            self.startCommandTimeout()
            self.onWakeWordDetected?()
        }
    }

    private var isUnavailable: Bool {
        if case .unavailable = state { return true }
        return false
    }

    // MARK: - Recognition session

    private func startRecognitionSession() {
        guard !isPausedForSpeechOutput else { return }

        tearDownRecognition()

        let localeIdentifier = settings.text(ptBR: "pt-BR", en: "en-US")
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            state = .unavailable(
                settings.text(
                    ptBR: "Reconhecimento de fala indisponível neste Mac.",
                    en: "Speech recognition unavailable on this Mac."
                )
            )
            return
        }
        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        if !startAudioEngineIfNeeded(feeding: request) {
            state = .unavailable(
                settings.text(
                    ptBR: "Não foi possível acessar o microfone.",
                    en: "Could not access the microphone."
                )
            )
            return
        }

        commandStartOffset = nil
        capturedTranscript = ""
        // Se a sessão anterior terminou logo após a wake word, a nova sessão
        // inteira é tratada como o comando (o transcript foi zerado).
        if isAwaitingCommand {
            commandStartOffset = 0
            state = .capturingCommand
        } else {
            state = .listening
        }

        sessionGeneration += 1
        let generation = sessionGeneration
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, generation == self.sessionGeneration else { return }
                self.handleRecognition(result: result, error: error)
            }
        }

        if !isManualSession {
            scheduleSessionRestart()
        }
    }

    private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            processTranscript(result.bestTranscription.formattedString, isFinal: result.isFinal)
        }

        if error != nil || result?.isFinal == true {
            // Sessão terminou (limite de duração, silêncio longo ou erro): reinicia se ainda ativo.
            guard state != .disabled, !isUnavailable else { return }
            let pendingCommand = pendingCommandText()
            if let pendingCommand, !pendingCommand.isEmpty {
                finalizeCommand(pendingCommand)
            } else {
                restartAfterDelay()
            }
        }
    }

    private var lastFullTranscript: String = ""

    private func processTranscript(_ transcript: String, isFinal: Bool) {
        lastFullTranscript = transcript
        let normalized = VoiceCommandParser.normalize(transcript)

        if commandStartOffset == nil {
            guard let range = rangeOfWakeWord(in: normalized) else { return }
            commandStartOffset = normalized.distance(from: normalized.startIndex, to: range.upperBound)
            isAwaitingCommand = true
            state = .capturingCommand
            startCommandTimeout()
            onWakeWordDetected?()
        }

        let commandText = pendingCommandText() ?? ""
        capturedTranscript = commandText
        if !commandText.isEmpty {
            onPartialCommand?(commandText)
        }

        if isFinal, !commandText.isEmpty {
            finalizeCommand(commandText)
        } else {
            restartSilenceTimer()
        }
    }

    /// Texto após a wake word, extraído do transcript completo mais recente.
    /// Se a sessão foi reiniciada após a wake word (transcript zerado),
    /// o transcript inteiro é o comando.
    private func pendingCommandText() -> String? {
        guard commandStartOffset != nil else { return nil }

        // Extrai sufixo do transcript original preservando caixa/acentos.
        let folded = lastFullTranscript
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()

        let start: String.Index
        if let foldedRange = rangeOfWakeWord(in: folded) {
            let offset = folded.distance(from: folded.startIndex, to: foldedRange.upperBound)
            guard let mapped = lastFullTranscript.index(
                lastFullTranscript.startIndex,
                offsetBy: offset,
                limitedBy: lastFullTranscript.endIndex
            ) else { return nil }
            start = mapped
        } else if isAwaitingCommand {
            start = lastFullTranscript.startIndex
        } else {
            return nil
        }

        return String(lastFullTranscript[start...])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func restartSilenceTimer() {
        guard commandStartOffset != nil else { return }
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let command = self.pendingCommandText() ?? ""
                // Só finaliza quando há comando; se vazio, continua aguardando
                // dentro da janela de timeout (usuário pode ter pausado após a wake word).
                if !command.isEmpty {
                    self.finalizeCommand(command)
                }
            }
        }
    }

    private func finalizeCommand(_ command: String) {
        silenceTimer?.invalidate()
        silenceTimer = nil
        cancelCommandTimeout()

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        commandStartOffset = nil
        isAwaitingCommand = false

        if !trimmed.isEmpty {
            onCommandCaptured?(trimmed)
        }

        concludeCaptureCycle()
    }

    // MARK: - Janela de comando

    private func startCommandTimeout() {
        cancelCommandTimeout()
        commandTimeoutTimer = Timer.scheduledTimer(withTimeInterval: commandTimeoutInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isAwaitingCommand else { return }
                let command = self.pendingCommandText() ?? ""
                if !command.isEmpty {
                    self.finalizeCommand(command)
                    return
                }
                self.isAwaitingCommand = false
                self.commandStartOffset = nil
                self.onCaptureCancelled?()
                self.concludeCaptureCycle()
            }
        }
    }

    private func cancelCommandTimeout() {
        commandTimeoutTimer?.invalidate()
        commandTimeoutTimer = nil
    }

    // MARK: - Wake word

    /// Variantes aceitas: o reconhecedor pode transcrever "clipe" como "clip"
    /// (e vice-versa). Mais longas primeiro para não truncar o sufixo.
    private func wakeWordVariants() -> [String] {
        let base = normalizedWakeWord()
        var variants = [base]
        if base.hasSuffix("e") {
            variants.append(String(base.dropLast()))
        } else {
            variants.append(base + "e")
        }
        return variants.sorted { $0.count > $1.count }
    }

    private func rangeOfWakeWord(in text: String) -> Range<String.Index>? {
        for variant in wakeWordVariants() {
            if let range = text.range(of: variant, options: .backwards) {
                return range
            }
        }
        return nil
    }

    /// Fim de captura: em sessão manual desliga o microfone por completo;
    /// em escuta contínua reinicia a sessão de reconhecimento.
    private func concludeCaptureCycle() {
        if isManualSession {
            isManualSession = false
            tearDownRecognition()
            stopAudioEngine()
            state = .disabled
            return
        }
        restartAfterDelay()
    }

    private func restartAfterDelay() {
        guard !isRestartScheduled, !isPausedForSpeechOutput else { return }
        isRestartScheduled = true
        tearDownRecognition(keepEngine: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.isRestartScheduled = false
            guard self.state != .disabled else { return }
            self.startRecognitionSession()
        }
    }

    private func scheduleSessionRestart() {
        sessionRestartTimer?.invalidate()
        sessionRestartTimer = Timer.scheduledTimer(withTimeInterval: sessionRestartInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .listening, !self.isPausedForSpeechOutput else { return }
                self.startRecognitionSession()
            }
        }
    }

    private func normalizedWakeWord() -> String {
        let word = VoiceCommandParser.normalize(settings.voiceWakeWord)
        return word.isEmpty ? "clipe" : word
    }

    // MARK: - Audio engine

    private func startAudioEngineIfNeeded(feeding request: SFSpeechAudioBufferRecognitionRequest) -> Bool {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return false }

        inputNode.removeTap(onBus: 0)
        // Captura o request da sessão atual; o tap é reinstalado a cada sessão.
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        if !isEngineRunning {
            audioEngine.prepare()
            do {
                try audioEngine.start()
                isEngineRunning = true
            } catch {
                NSLog("[ClipFlow] Falha ao iniciar AVAudioEngine: \(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    private func stopAudioEngine() {
        audioEngine.inputNode.removeTap(onBus: 0)
        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
    }

    private func tearDownRecognition(keepEngine: Bool = false) {
        silenceTimer?.invalidate()
        silenceTimer = nil
        sessionRestartTimer?.invalidate()
        sessionRestartTimer = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        commandStartOffset = nil
        lastFullTranscript = ""

        if !keepEngine {
            stopAudioEngine()
        }
    }

    // MARK: - Authorization

    static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func requestMicrophoneAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
