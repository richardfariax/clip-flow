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
    private var currentAudioURL: URL?

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

        onFinish = completion

        Task {
            await speakWithNeuralVoice(text, languageCode: languageCode)
        }
    }

    func stop() {
        onFinish = nil

        audioPlayer?.stop()
        audioPlayer = nil
        cleanupCurrentAudio()

        fallbackSynthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Edge TTS (voz neural)

    private func speakWithNeuralVoice(_ text: String, languageCode: String) async {
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
            currentAudioURL = outputURL
            playAudio(at: outputURL)
        } catch {
            NSLog("[ClipFlow] Edge TTS falhou, usando voz do sistema: \(error.localizedDescription)")
            speakWithSystemVoice(text, languageCode: languageCode)
        }
    }

    private func playAudio(at url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            audioPlayer = player
            player.play()
        } catch {
            NSLog("[ClipFlow] Falha ao reproduzir áudio TTS: \(error.localizedDescription)")
            finishSpeaking()
        }
    }

    /// Vozes neurais Edge TTS — mais naturais que as vozes do macOS.
    /// pt-BR-ThalitaNeural: feminina, moderna e expressiva (ideal para assistente).
    /// en-US-JennyNeural: feminina, natural e clara.
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
        fallbackSynthesizer.speak(utterance)
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

    private func finishSpeaking() {
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

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.finishSpeaking()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onFinish = nil
        }
    }
}
