import AppKit
import CoreGraphics
import Foundation
import Vision

enum ScreenAnalysisError: Error {
    case captureFailed
    case permissionDenied
    case noTextFound
}

/// Captura a tela principal e extrai texto visível com Vision (OCR local).
@MainActor
final class ScreenAnalysisService {
    private let maxSpokenCharacters = 420
    private let maxLines = 10

    /// - Parameters:
    ///   - languageCode: "pt" ou "en" — idioma preferido do OCR.
    ///   - onPrepareCapture: chamado antes da captura (ex.: esconder overlay do Clip).
    ///   - completion: descrição falada do conteúdo visível.
    func describeVisibleScreen(
        languageCode: String,
        onPrepareCapture: @escaping () -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        if #available(macOS 10.15, *) {
            guard CGPreflightScreenCaptureAccess() else {
                _ = CGRequestScreenCaptureAccess()
                completion(.failure(ScreenAnalysisError.permissionDenied))
                return
            }
        }

        onPrepareCapture()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }

            guard let image = Self.captureMainDisplayImage() else {
                completion(.failure(ScreenAnalysisError.captureFailed))
                return
            }

            let appName = Self.frontmostApplicationName()
            let ocrLanguages = Self.ocrLanguages(for: languageCode)
            let maxLines = self.maxLines
            let maxCharacters = self.maxSpokenCharacters

            Task.detached(priority: .userInitiated) {
                let lines = Self.recognizeText(in: image, languages: ocrLanguages)
                let description = Self.buildDescription(
                    appName: appName,
                    lines: lines,
                    languageCode: languageCode,
                    maxLines: maxLines,
                    maxCharacters: maxCharacters
                )

                await MainActor.run {
                    if let description {
                        completion(.success(description))
                    } else {
                        completion(.failure(ScreenAnalysisError.noTextFound))
                    }
                }
            }
        }
    }

    // MARK: - Capture

    private static func captureMainDisplayImage() -> CGImage? {
        CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    }

    private static func frontmostApplicationName() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return app.localizedName
    }

    // MARK: - OCR

    private struct RecognizedLine {
        let text: String
        let confidence: Float
        let y: CGFloat
    }

    private static func ocrLanguages(for languageCode: String) -> [String] {
        if languageCode.lowercased().hasPrefix("pt") {
            return ["pt-BR", "en-US"]
        }
        return ["en-US", "pt-BR"]
    }

    private static func recognizeText(in image: CGImage, languages: [String]) -> [RecognizedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("[ClipFlow] OCR falhou: \(error.localizedDescription)")
            return []
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return []
        }

        var lines: [RecognizedLine] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first,
                  candidate.confidence > 0.25 else { continue }

            let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { continue }

            lines.append(RecognizedLine(
                text: trimmed,
                confidence: candidate.confidence,
                y: 1 - observation.boundingBox.midY
            ))
        }

        return lines
            .sorted { lhs, rhs in
                if abs(lhs.y - rhs.y) < 0.02 {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.y < rhs.y
            }
    }

    // MARK: - Description

    private static func buildDescription(
        appName: String?,
        lines: [RecognizedLine],
        languageCode: String,
        maxLines: Int,
        maxCharacters: Int
    ) -> String? {
        var uniqueLines: [String] = []
        var seen: Set<String> = []

        for line in lines {
            let key = line.text.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            uniqueLines.append(line.text)
            if uniqueLines.count >= maxLines { break }
        }

        let isPortuguese = languageCode.lowercased().hasPrefix("pt")

        if uniqueLines.isEmpty {
            if let appName {
                return isPortuguese
                    ? "Estou vendo o \(appName), mas não encontrei texto legível na tela."
                    : "I'm looking at \(appName), but I couldn't find readable text on the screen."
            }
            return isPortuguese
                ? "Não encontrei texto legível na tela."
                : "I couldn't find readable text on the screen."
        }

        var body = uniqueLines.joined(separator: ". ")
        if body.count > maxCharacters {
            body = String(body.prefix(maxCharacters))
            if let lastSpace = body.lastIndex(of: " ") {
                body = String(body[..<lastSpace])
            }
            body += "..."
        }

        if let appName {
            return isPortuguese
                ? "Na tela do \(appName), leio: \(body)."
                : "On \(appName)'s screen, I read: \(body)."
        }

        return isPortuguese
            ? "Na tela, leio: \(body)."
            : "On screen, I read: \(body)."
    }
}
