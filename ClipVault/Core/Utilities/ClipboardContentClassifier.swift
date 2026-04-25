import CryptoKit
import Foundation

enum ClipboardContentClassifier {
    static func classifyText(_ text: String) -> ClipboardTextSubtype {
        if text.count >= 500 {
            return .longText
        }

        if looksLikeEmail(text) {
            return .email
        }

        if looksLikeURL(text) {
            return .url
        }

        if looksLikeCode(text) {
            return .code
        }

        return .plain
    }

    static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func looksLikeEmail(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return false
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        return detector.matches(in: trimmed, options: [], range: range).contains { result in
            result.url?.scheme == "mailto"
        }
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n") else {
            return false
        }
        guard let url = URL(string: trimmed), let scheme = url.scheme else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let codeTokens = ["{", "}", "=>", "func ", "class ", "struct ", "let ", "var ", "import ", "SELECT ", "<div", "</"]
        let score = codeTokens.reduce(0) { partialResult, token in
            partialResult + (text.contains(token) ? 1 : 0)
        }
        return score >= 2
    }
}
