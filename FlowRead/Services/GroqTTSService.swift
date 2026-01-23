// GroqTTSService.swift
// FlowRead - Groq Text-to-Speech API integration

import Foundation

/// Errors specific to Groq TTS operations
enum GroqTTSError: Error, LocalizedError {
    case noAPIKeysConfigured
    case allKeysExhausted
    case rateLimited
    case networkError(String)
    case invalidResponse
    case invalidAudioData
    
    var errorDescription: String? {
        switch self {
        case .noAPIKeysConfigured:
            return "No API keys configured. Please add your Groq API keys."
        case .allKeysExhausted:
            return "All API keys have been exhausted or rate limited."
        case .rateLimited:
            return "Rate limit reached for current API key."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from Groq API."
        case .invalidAudioData:
            return "Invalid audio data received."
        }
    }
}

/// Available Groq TTS voices (Canopy Labs Orpheus - Updated Jan 2026)
enum GroqVoice: String, CaseIterable, Identifiable {
    // Female voices
    case autumn = "autumn"
    case diana = "diana"
    case hannah = "hannah"
    
    // Male voices
    case austin = "austin"
    case daniel = "daniel"
    case troy = "troy"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var gender: String {
        switch self {
        case .autumn, .diana, .hannah:
            return "Female"
        case .austin, .daniel, .troy:
            return "Male"
        }
    }
}

/// Manages Groq TTS API calls with automatic key rotation
actor GroqTTSService {
    private var apiKeys: [String] = []
    private var currentKeyIndex: Int = 0
    private var failedKeys: Set<Int> = []
    
    private let baseURL = "https://api.groq.com/openai/v1/audio/speech"
    private var selectedVoice: GroqVoice = .hannah  // Default to Hannah voice
    
    private let session: URLSession
    
    // Audio response format - Groq Orpheus supports wav (default) and mp3
    private let responseFormat = "wav"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Load API keys inline to avoid actor isolation issues
        var keys: [String] = []
        
        // Try environment variables first (GROQ_API_KEY_1 through GROQ_API_KEY_5)
        for i in 1...5 {
            if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY_\(i)"],
               !key.isEmpty {
                keys.append(key)
            }
        }
        
        // Also check single GROQ_API_KEY
        if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"],
           !key.isEmpty,
           !keys.contains(key) {
            keys.insert(key, at: 0)
        }
        
        // Try loading from config file
        if keys.isEmpty {
            let configPaths = [
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowread/api_keys.json"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/flowread/api_keys.json")
            ]
            
            for path in configPaths {
                if FileManager.default.fileExists(atPath: path.path) {
                    do {
                        let data = try Data(contentsOf: path)
                        let config = try JSONDecoder().decode(APIKeyConfig.self, from: data)
                        keys = config.groqAPIKeys.filter { !$0.isEmpty }
                        break
                    } catch {
                        print("Failed to load API keys from \(path): \(error)")
                    }
                }
            }
        }
        
        self.apiKeys = keys
    }
    
    /// Reload API keys (can be called after config changes)
    
    private func loadKeysFromConfigFile() -> [String] {
        let configPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowread/api_keys.json"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/flowread/api_keys.json")
        ]
        
        for path in configPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    let data = try Data(contentsOf: path)
                    let config = try JSONDecoder().decode(APIKeyConfig.self, from: data)
                    return config.groqAPIKeys.filter { !$0.isEmpty }
                } catch {
                    print("Failed to load API keys from \(path): \(error)")
                }
            }
        }
        
        return []
    }
    
    /// Reload API keys from config file
    func reloadKeys() {
        let keys = loadKeysFromConfigFile()
        if !keys.isEmpty {
            self.apiKeys = keys
            self.currentKeyIndex = 0
            self.failedKeys.removeAll()
        }
    }
    
    /// Set the voice for TTS
    func setVoice(_ voice: GroqVoice) {
        self.selectedVoice = voice
    }
    
    /// Add API keys programmatically
    func addAPIKeys(_ keys: [String]) {
        let newKeys = keys.filter { !$0.isEmpty && !apiKeys.contains($0) }
        apiKeys.append(contentsOf: newKeys)
    }
    
    /// Synthesize text to audio
    /// Automatically handles long text by splitting into chunks
    /// Returns nil for invalid text (allows skipping without error)
    func synthesize(text: String) async throws -> Data? {
        guard !apiKeys.isEmpty else {
            throw GroqTTSError.noAPIKeysConfigured
        }
        
        // Validate text before processing
        guard isValidForTTS(text) else {
            print("[TTS] Skipping invalid text: '\(text.prefix(30))...'")
            return nil  // Return nil for invalid text - let caller handle skip
        }
        
        // Sanitize text to remove problematic characters
        let sanitizedText = sanitizeText(text)
        
        // Double-check after sanitization
        guard isValidForTTS(sanitizedText) else {
            print("[TTS] Text invalid after sanitization, skipping")
            return nil
        }
        
        // IMPORTANT: Groq Orpheus TTS has a 200 character limit per request!
        // Using 180 to leave some buffer
        let maxChunkLength = 180
        
        // If text is short enough, synthesize directly
        if sanitizedText.count <= maxChunkLength {
            return try await synthesizeSingle(text: sanitizedText)
        }
        
        // Split long text into chunks and synthesize each
        let chunks = splitTextIntoChunks(sanitizedText, maxLength: maxChunkLength)
            .filter { isValidForTTS($0) }  // Filter out invalid chunks
        
        guard !chunks.isEmpty else {
            print("[TTS] No valid chunks after filtering")
            return nil
        }
        
        var audioDataPieces: [Data] = []
        
        print("[TTS] Splitting text into \(chunks.count) valid chunks")
        
        for (index, chunk) in chunks.enumerated() {
            print("[TTS] Synthesizing chunk \(index + 1)/\(chunks.count) (\(chunk.count) chars)")
            let audioData = try await synthesizeSingle(text: chunk)
            audioDataPieces.append(audioData)
        }
        
        // Combine audio chunks (for WAV, simply concatenate)
        return audioDataPieces.reduce(Data()) { $0 + $1 }
    }
    
    /// Check if text is valid for TTS (must be meaningful content)
    func isValidForTTS(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must not be empty
        guard !trimmed.isEmpty else { return false }
        
        // Must contain at least one letter or digit
        let hasLetterOrDigit = trimmed.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        
        guard hasLetterOrDigit else { return false }
        
        // Count alphanumeric characters
        let alphanumericCount = trimmed.unicodeScalars.filter { 
            CharacterSet.alphanumerics.contains($0) 
        }.count
        
        // Reject if too few alphanumeric characters
        guard alphanumericCount >= 3 else { return false }
        
        // Count words
        let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // For very short text (under 10 chars), require at least 2 words
        // This prevents single-word nonsense like "I" or "A" being read
        if trimmed.count < 10 && words.count < 2 {
            // Exception: allow if it's a proper short word/phrase
            // Like "Hello!" or "Yes." or "Chapter 1."
            if trimmed.count < 5 && !trimmed.contains(" ") {
                return false  // Single short word - skip
            }
        }
        
        return true
    }
    
    /// Sanitize text to remove characters that might cause API issues
    private func sanitizeText(_ text: String) -> String {
        var sanitized = text
        
        // Remove control characters except newlines
        sanitized = sanitized.unicodeScalars.filter { scalar in
            scalar == "\n" || scalar == "\r" || !CharacterSet.controlCharacters.contains(scalar)
        }.map(String.init).joined()
        
        // Replace multiple spaces with single space
        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Replace newlines with spaces for TTS
        sanitized = sanitized.replacingOccurrences(of: "\n", with: " ")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: " ")
        
        // Trim whitespace
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return sanitized
    }
    
    /// Split text into smaller chunks at natural break points
    private func splitTextIntoChunks(_ text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        // Split by sentences first
        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")
        let sentences = text.components(separatedBy: sentenceDelimiters)
        
        for (index, sentence) in sentences.enumerated() {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            // Add back the delimiter if not the last sentence
            let delimiter = index < sentences.count - 1 ? ". " : ""
            let sentenceWithDelimiter = trimmed + delimiter
            
            if currentChunk.isEmpty {
                currentChunk = sentenceWithDelimiter
            } else if (currentChunk + sentenceWithDelimiter).count <= maxLength {
                currentChunk += sentenceWithDelimiter
            } else {
                // Current chunk is full, save it and start a new one
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentChunk = sentenceWithDelimiter
            }
            
            // Handle case where a single sentence is too long
            if currentChunk.count > maxLength {
                // Split by words
                let words = currentChunk.split(separator: " ")
                currentChunk = ""
                
                for word in words {
                    if currentChunk.isEmpty {
                        currentChunk = String(word)
                    } else if (currentChunk + " " + word).count <= maxLength {
                        currentChunk += " " + word
                    } else {
                        chunks.append(currentChunk)
                        currentChunk = String(word)
                    }
                }
            }
        }
        
        // Don't forget the last chunk
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks
    }
    
    /// Synthesize a single text chunk (internal)
    private func synthesizeSingle(text: String) async throws -> Data {
        // Reset failed keys if all have failed (allow retry)
        if failedKeys.count >= apiKeys.count {
            failedKeys.removeAll()
            currentKeyIndex = 0
        }
        
        // Try each available key
        var lastError: Error?
        let maxAttempts = apiKeys.count
        
        for _ in 0..<maxAttempts {
            // Skip failed keys
            while failedKeys.contains(currentKeyIndex) {
                currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
                if failedKeys.count >= apiKeys.count {
                    throw GroqTTSError.allKeysExhausted
                }
            }
            
            let apiKey = apiKeys[currentKeyIndex]
            
            do {
                let audioData = try await makeRequest(text: text, apiKey: apiKey)
                
                // Rotate to next key for load balancing
                currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
                
                return audioData
            } catch let error as GroqTTSError {
                lastError = error
                
                switch error {
                case .rateLimited:
                    failedKeys.insert(currentKeyIndex)
                    currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
                    continue
                case .networkError:
                    // Network errors might be temporary, don't mark key as failed
                    throw error
                default:
                    throw error
                }
            } catch {
                lastError = error
                currentKeyIndex = (currentKeyIndex + 1) % apiKeys.count
            }
        }
        
        throw lastError ?? GroqTTSError.allKeysExhausted
    }
    
    private func makeRequest(text: String, apiKey: String) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw GroqTTSError.invalidResponse
        }
        
        // Log the request details for debugging
        print("[TTS Request] Text length: \(text.count) chars")
        print("[TTS Request] Text preview: \(String(text.prefix(50)))...")
        print("[TTS Request] Voice: \(selectedVoice.rawValue)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "canopylabs/orpheus-v1-english",  // Groq Orpheus English model
            "input": text,
            "voice": selectedVoice.rawValue,
            "response_format": responseFormat
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GroqTTSError.invalidResponse
            }
            
            print("[TTS Response] Status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                if data.isEmpty {
                    throw GroqTTSError.invalidAudioData
                }
                print("[TTS Success] Received \(data.count) bytes of audio")
                return data
                
            case 429:
                print("[TTS Error] Rate limited")
                throw GroqTTSError.rateLimited
                
            case 401, 403:
                print("[TTS Error] Auth error")
                throw GroqTTSError.networkError("Invalid or expired API key")
                
            case 400:
                // Parse error response to get actual error message
                let errorMessage = parseErrorResponse(data)
                print("[TTS Error 400] \(errorMessage)")
                print("[TTS Error 400] Text was: '\(text)'")
                throw GroqTTSError.networkError("API Error: \(errorMessage)")
                
            case 500...599:
                let errorMessage = parseErrorResponse(data)
                print("[TTS Error \(httpResponse.statusCode)] \(errorMessage)")
                throw GroqTTSError.networkError("Server error (\(httpResponse.statusCode)): \(errorMessage)")
                
            default:
                let errorMessage = parseErrorResponse(data)
                print("[TTS Error \(httpResponse.statusCode)] \(errorMessage)")
                throw GroqTTSError.networkError("Error (\(httpResponse.statusCode)): \(errorMessage)")
            }
        } catch let error as GroqTTSError {
            throw error
        } catch {
            throw GroqTTSError.networkError(error.localizedDescription)
        }
    }
    
    /// Check if service is configured
    var isConfigured: Bool {
        !apiKeys.isEmpty
    }
    
    /// Get count of available (non-failed) keys
    var availableKeyCount: Int {
        apiKeys.count - failedKeys.count
    }
    
    /// Parse error response from API to extract the actual error message
    private func parseErrorResponse(_ data: Data) -> String {
        // Try to parse as JSON error response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Check for OpenAI-style error format
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            // Check for simple message field
            if let message = json["message"] as? String {
                return message
            }
            // Check for detail field
            if let detail = json["detail"] as? String {
                return detail
            }
            // Return the whole JSON as string for debugging
            return String(data: data, encoding: .utf8) ?? "Unknown error"
        }
        // Not JSON, return raw string
        return String(data: data, encoding: .utf8) ?? "Unknown error (no response body)"
    }
}

// MARK: - API Key Config

private struct APIKeyConfig: Codable {
    let groqAPIKeys: [String]
    
    enum CodingKeys: String, CodingKey {
        case groqAPIKeys = "groq_api_keys"
    }
}
