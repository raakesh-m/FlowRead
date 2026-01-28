// KokoroTokenizer.swift
// FlowRead - Tokenizer for Kokoro TTS models

import Foundation

/// Tokenizer for Kokoro TTS models
class KokoroTokenizer {
    private let vocab: [String: Int]
    private let reverseVocab: [Int: String]

    /// Special tokens
    private let padToken: Int
    private let unkToken: Int

    init(tokenizerPath: URL) throws {
        guard FileManager.default.fileExists(atPath: tokenizerPath.path) else {
            throw TokenizerError.tokenizerFileNotFound
        }

        let data = try Data(contentsOf: tokenizerPath)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let vocabDict = json?["model"] as? [String: Any],
              let vocabData = vocabDict["vocab"] as? [String: Int] else {
            throw TokenizerError.invalidTokenizerFormat
        }

        self.vocab = vocabData

        // Create reverse mapping
        var reverse = [Int: String]()
        for (token, id) in vocabData {
            reverse[id] = token
        }
        self.reverseVocab = reverse

        // Get special tokens (assuming standard BPE format)
        self.padToken = vocabData["[PAD]"] ?? 0
        self.unkToken = vocabData["[UNK]"] ?? 1

        print("[KokoroTokenizer] Loaded with \(vocab.count) tokens")
    }

    /// Tokenize text into token IDs
    func encode(_ text: String) -> [Int64] {
        // Basic character-level tokenization for now
        // In a production implementation, this would use BPE or WordPiece
        let normalized = normalizeText(text)
        var tokens: [Int64] = []

        for char in normalized {
            let charStr = String(char)
            if let tokenId = vocab[charStr] {
                tokens.append(Int64(tokenId))
            } else {
                tokens.append(Int64(unkToken))
            }
        }

        return tokens
    }

    /// Decode token IDs back to text
    func decode(_ tokens: [Int64]) -> String {
        let strings = tokens.compactMap { reverseVocab[Int($0)] }
        return strings.joined()
    }

    /// Normalize text for tokenization
    private func normalizeText(_ text: String) -> String {
        // Convert to lowercase
        let lowercased = text.lowercased()

        // Remove extra whitespace
        let normalized = lowercased
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return normalized
    }
}

// MARK: - Errors

enum TokenizerError: Error, LocalizedError {
    case tokenizerFileNotFound
    case invalidTokenizerFormat
    case tokenizationFailed(String)

    var errorDescription: String? {
        switch self {
        case .tokenizerFileNotFound:
            return "Tokenizer file not found"
        case .invalidTokenizerFormat:
            return "Invalid tokenizer format"
        case .tokenizationFailed(let message):
            return "Tokenization failed: \(message)"
        }
    }
}
