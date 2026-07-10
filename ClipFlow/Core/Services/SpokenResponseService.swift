import AVFoundation
import Foundation
import SwiftEdgeTTS

/// Respostas faladas com voz neural Microsoft Edge TTS (realista, online).
/// Faz fallback para a síntese nativa do macOS se a rede falhar.
@MainActor
final class SpokenResponseService: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    private let edgeTTS = EdgeTTSService()
    private let fallbackSynthesizer = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var onFinish: (() -> Void)?
    private var onPlaybackStarted: (() -> Void)?
    private var currentAudioURL: URL?
    private var meteringTimer: Timer?
    private var didNotifyPlaybackStarted = false

    /// 0...1 — energia do áudio enquanto o Clip fala (HUD).
    private(set) var speechLevel: Double = 0
    /// 0...1 — progresso da fala no texto (para legenda sincronizada).
    private(set) var speechProgress: Double = 0

    /// Chamado quando o áudio realmente começa a tocar (não quando a síntese inicia).
    var playbackStartedHandler: (() -> Void)?

    /// Nível atual para o HUD (atualizado em tempo real).
    var speechLevelHandler: ((Double) -> Void)?
    /// Progresso 0...1 da leitura do texto.
    var speechProgressHandler: ((Double) -> Void)?

    private var fallbackSpeechStartedAt: TimeInterval?
    private var fallbackEstimatedDuration: TimeInterval = 0
    private var speakGeneration = 0

    override init() {
        super.init()
        fallbackSynthesizer.delegate = self
    }

    /// Fala o texto e chama `completion` quando a fala termina (ou é cancelada).
    func speak(_ text: String, languageCode: String, completion: (() -> Void)? = nil) {
        stop()

        guard !text.isEmpty else {
            completion?()
            return
        }

        speakGeneration += 1
        let generation = speakGeneration
        onFinish = completion
        didNotifyPlaybackStarted = false
        speechLevel = 0
        speechProgress = 0
        speechProgressHandler?(0)
        fallbackSpeechStartedAt = nil
        fallbackEstimatedDuration = 0

        Task {
            await speakWithNeuralVoice(text, languageCode: languageCode, generation: generation)
        }
    }

    func stop() {
        speakGeneration += 1
        stopMetering()
        onFinish = nil
        onPlaybackStarted = nil
        didNotifyPlaybackStarted = false
        speechLevel = 0
        speechProgress = 0
        speechLevelHandler?(0)
        speechProgressHandler?(0)
        fallbackSpeechStartedAt = nil

        audioPlayer?.stop()
        audioPlayer = nil
        cleanupCurrentAudio()

        fallbackSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Edge TTS (voz neural)

    private func speakWithNeuralVoice(_ text: String, languageCode: String, generation: Int) async {
        let voice = Self.neuralVoice(for: languageCode)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipflow-tts-\(UUID().uuidString).mp3")

        do {
            _ = try await edgeTTS.synthesize(
                text: text,
                voice: voice,
                outputURL: outputURL,
                rate: "+5%",
                volume: nil,
                pitch: nil
            )
            guard generation == speakGeneration else {
                try? FileManager.default.removeItem(at: outputURL)
                return
            }
            currentAudioURL = outputURL
            playAudio(at: outputURL)
        } catch {
            guard generation == speakGeneration else { return }
            NSLog("[ClipFlow] Edge TTS falhou, usando voz do sistema: \(error.localizedDescription)")
            speakWithSystemVoice(text, languageCode: languageCode)
        }
    }

    private func playAudio(at url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.isMeteringEnabled = true
            player.prepareToPlay()
            audioPlayer = player
            player.play()
            notifyPlaybackStartedIfNeeded()
            startMetering()
        } catch {
            NSLog("[ClipFlow] Falha ao reproduzir áudio TTS: \(error.localizedDescription)")
            finishSpeaking()
        }
    }

    /// Vozes neurais Edge TTS — mais naturais que as vozes do macOS.
    static func neuralVoice(for languageCode: String) -> String {
        let prefix = languageCode.lowercased().prefix(2)
        switch prefix {
        case "pt":
            return "pt-BR-ThalitaNeural"
        default:
            return "en-US-JennyNeural"
        }
    }

    // MARK: - Fallback (macOS)

    private func speakWithSystemVoice(_ text: String, languageCode: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestSystemVoice(for: languageCode)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // Estimativa para sincronizar a legenda no fallback.
        fallbackEstimatedDuration = max(2.2, Double(text.count) * 0.058)
        fallbackSpeechStartedAt = CACurrentMediaTime()
        fallbackSynthesizer.speak(utterance)
        notifyPlaybackStartedIfNeeded()
        startFallbackPulse()
    }

    private func bestSystemVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let target = languageCode.lowercased()
        let prefix = String(target.prefix(2))

        let exact = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased() == target }
        let related = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.lowercased().hasPrefix(prefix) }

        for pool in [exact, related] {
            if let premium = pool.first(where: { $0.quality == .premium }) {
                return premium
            }
        }
        for pool in [exact, related] {
            if let enhanced = pool.first(where: { $0.quality == .enhanced }) {
                return enhanced
            }
        }
        return AVSpeechSynthesisVoice(language: languageCode)
    }

    private func notifyPlaybackStartedIfNeeded() {
        guard !didNotifyPlaybackStarted else { return }
        didNotifyPlaybackStarted = true
        playbackStartedHandler?()
    }

    private func startMetering() {
        stopMetering()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetering()
            }
        }
    }

    private func startFallbackPulse() {
        stopMetering()
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.fallbackSynthesizer.isSpeaking else {
                    self.publishProgress(1)
                    self.speechLevel = 0
                    self.speechLevelHandler?(0)
                    return
                }
                let t = Date().timeIntervalSinceReferenceDate
                let level = 0.35 + 0.55 * abs(sin(t * 11.0)) * abs(sin(t * 7.3))
                self.speechLevel = level
                self.speechLevelHandler?(level)

                if let started = self.fallbackSpeechStartedAt, self.fallbackEstimatedDuration > 0 {
                    let elapsed = CACurrentMediaTime() - started
                    self.publishProgress(min(0.995, elapsed / self.fallbackEstimatedDuration))
                }
            }
        }
    }

    private func updateMetering() {
        guard let player = audioPlayer, player.isPlaying else {
            speechLevel = 0
            speechLevelHandler?(0)
            return
        }
        player.updateMeters()
        let power = Double(player.averagePower(forChannel: 0))
        // power típico: -60 (silêncio) a 0 (alto)
        let normalized = max(0, min(1, (power + 45) / 40))
        speechLevel = normalized
        speechLevelHandler?(normalized)

        let duration = player.duration
        if duration > 0.05 {
            // Leve avanço para a legenda não ficar atrás do áudio.
            let raw = player.currentTime / duration
            publishProgress(min(1, max(0, raw * 1.02)))
        }
    }

    private func publishProgress(_ value: Double) {
        let clamped = max(0, min(1, value))
        speechProgress = clamped
        speechProgressHandler?(clamped)
    }

    private func stopMetering() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func finishSpeaking() {
        stopMetering()
        publishProgress(1)
        speechLevel = 0
        speechLevelHandler?(0)
        cleanupCurrentAudio()
        let callback = onFinish
        onFinish = nil
        callback?()
    }

    private func cleanupCurrentAudio() {
        if let url = currentAudioURL {
            try? FileManager.default.removeItem(at: url)
            currentAudioURL = nil
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.finishSpeaking()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.finishSpeaking()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.notifyPlaybackStartedIfNeeded()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.stopMetering()
            self.speechLevel = 0
            self.speechProgress = 0
            self.speechLevelHandler?(0)
            self.speechProgressHandler?(0)
            self.onFinish = nil
        }
    }
}
