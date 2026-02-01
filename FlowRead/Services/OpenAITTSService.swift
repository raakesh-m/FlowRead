// OpenAITTSService.swift
// FlowRead - OpenAI Text-to-Speech API integration

import Foundation

/// Errors specific to OpenAI TTS operations
enum OpenAITTSError: Error, LocalizedError {
    case noAPIKeyConfigured
    case rateLimited
    case networkError(String)
    case invalidResponse
    case invalidAudioData
    case quotaExceeded
    
    var errorDescription: String? {
        switch self {
        case .noAPIKeyConfigured:
            return "No OpenAI API key configured. Please add your API key in Preferences."
        case .rateLimited:
            return "Rate limit reached. Please wait a moment."
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .invalidAudioData:
            return "Invalid audio data received."
        case .quotaExceeded:
            return "OpenAI quota exceeded. Please check your billing."
        }
    }
}

/// Available OpenAI TTS voices
enum OpenAIVoice: String, CaseIterable, Identifiable {
    case alloy = "alloy"
    case echo = "echo"
    case fable = "fable"
    case onyx = "onyx"
    case nova = "nova"
    case shimmer = "shimmer"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var gender: String {
        switch self {
        case .alloy:
            return "Neutral"
        case .echo:
            return "Male"
        case .fable:
            return "Neutral"
        case .onyx:
            return "Male"
        case .nova:
            return "Female"
        case .shimmer:
            return "Female"
        }
    }
    
    /// Short description of the voice characteristic
    var description: String {
        switch self {
        case .alloy:
            return "Versatile & balanced"
        case .echo:
            return "Warm & conversational"
        case .fable:
            return "Expressive & dynamic"
        case .onyx:
            return "Deep & authoritative"
        case .nova:
            return "Friendly & upbeat"
        case .shimmer:
            return "Clear & optimistic"
        }
    }
}

/// Available OpenAI TTS models
enum OpenAITTSModel: String, CaseIterable, Identifiable {
    case tts1 = "tts-1"
    case tts1HD = "tts-1-hd"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tts1:
            return "TTS-1 (Standard)"
        case .tts1HD:
            return "TTS-1-HD (High Quality)"
        }
    }
    
    var description: String {
        switch self {
        case .tts1:
            return "Faster, lower latency - $15/1M chars"
        case .tts1HD:
            return "Higher quality audio - $30/1M chars"
        }
    }
}

/// Manages OpenAI TTS API calls
actor OpenAITTSService {
    private var apiKey: String = ""
    
    private let baseURL = "https://api.openai.com/v1/audio/speech"
    private var selectedVoice: OpenAIVoice = .nova  // Default to Nova voice
    private var selectedModel: OpenAITTSModel = .tts1  // Default to standard model
    
    private let session: URLSession
    
    // Audio response format - OpenAI supports mp3, opus, aac, flac, wav, pcm
    private let responseFormat = "wav"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        // Load API key from various sources
        loadAPIKey()
    }
    
    /// Load API key from environment or config file
    private func loadAPIKey() {
        // Try environment variable first
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !key.isEmpty {
            apiKey = key
            return
        }
        
        // Try loading from config file
        let configPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".flowread/api_keys.json"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/flowread/api_keys.json")
        ]
        
        for path in configPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    let data = try Data(contentsOf: path)
                    let config = try JSONDecoder().decode(OpenAIKeyConfig.self, from: data)
                    if let key = config.openaiAPIKey, !key.isEmpty {
                        apiKey = key
                        return
                    }
                } catch {
                    print("[OpenAI TTS] Failed to load API key from \(path): \(error)")
                }
            }
        }
    }
    
    /// Reload API key from config file
    func reloadKey() {
        loadAPIKey()
    }
    
    /// Set the API key programmatically
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    /// Get the current API key (masked for display)
    func getMaskedAPIKey() -> String {
        guard !apiKey.isEmpty else { return "" }
        if apiKey.count <= 8 {
            return String(repeating: "*", count: apiKey.count)
        }
        let prefix = String(apiKey.prefix(4))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    /// Check if API key is configured
    func hasAPIKey() -> Bool {
        return !apiKey.isEmpty
    }
    
    /// Set the voice for TTS
    func setVoice(_ voice: OpenAIVoice) {
        self.selectedVoice = voice
    }
    
    /// Get current voice
    func getVoice() -> OpenAIVoice {
        return selectedVoice
    }
    
    /// Set the TTS model
    func setModel(_ model: OpenAITTSModel) {
        self.selectedModel = model
        print("[OpenAI TTS] Model changed to: \(model.displayName)")
    }
    
    /// Get current model
    func getModel() -> OpenAITTSModel {
        return selectedModel
    }
    
    /// Synthesize text to audio
    /// Automatically handles long text by splitting into chunks
    /// Returns nil for invalid text (allows skipping without error)
    func synthesize(text: String) async throws -> Data? {
        guard !apiKey.isEmpty else {
            throw OpenAITTSError.noAPIKeyConfigured
        }
        
        // Validate text before processing
        guard isValidForTTS(text) else {
            print("[OpenAI TTS] Skipping invalid text: '\(text.prefix(30))...'")
            return nil
        }
        
        // Sanitize text to remove problematic characters
        let sanitizedText = sanitizeText(text)
        
        // Double-check after sanitization
        guard isValidForTTS(sanitizedText) else {
            print("[OpenAI TTS] Text invalid after sanitization, skipping")
            return nil
        }
        
        // OpenAI TTS supports up to 4096 characters per request
        // Using 4000 to leave some buffer
        let maxChunkLength = 4000
        
        // If text is short enough, synthesize directly
        if sanitizedText.count <= maxChunkLength {
            return try await synthesizeSingle(text: sanitizedText)
        }
        
        // Split long text into chunks and synthesize each
        let chunks = splitTextIntoChunks(sanitizedText, maxLength: maxChunkLength)
            .filter { isValidForTTS($0) }
        
        guard !chunks.isEmpty else {
            print("[OpenAI TTS] No valid chunks after filtering")
            return nil
        }
        
        var audioDataPieces: [Data] = []
        
        print("[OpenAI TTS] Splitting text into \(chunks.count) valid chunks")
        
        for (index, chunk) in chunks.enumerated() {
            print("[OpenAI TTS] Synthesizing chunk \(index + 1)/\(chunks.count) (\(chunk.count) chars)")
            let audioData = try await synthesizeSingle(text: chunk)
            audioDataPieces.append(audioData)
        }
        
        // Combine audio chunks
        return combineWAVFiles(audioDataPieces)
    }
    
    /// Check if text is valid for TTS
    func isValidForTTS(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return false }
        
        let hasLetterOrDigit = trimmed.unicodeScalars.contains { scalar in
            CharacterSet.alphanumerics.contains(scalar)
        }
        
        guard hasLetterOrDigit else { return false }
        
        let alphanumericCount = trimmed.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }.count
        
        guard alphanumericCount >= 3 else { return false }
        
        return true
    }
    
    /// Sanitize text to remove problematic characters
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
            
            let delimiter = index < sentences.count - 1 ? ". " : ""
            let sentenceWithDelimiter = trimmed + delimiter
            
            if currentChunk.isEmpty {
                currentChunk = sentenceWithDelimiter
            } else if (currentChunk + sentenceWithDelimiter).count <= maxLength {
                currentChunk += sentenceWithDelimiter
            } else {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                currentChunk = sentenceWithDelimiter
            }
            
            // Handle case where a single sentence is too long
            if currentChunk.count > maxLength {
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
        
        if !currentChunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks
    }
    
    /// Synthesize a single text chunk
    private func synthesizeSingle(text: String) async throws -> Data {
        guard let url = URL(string: baseURL) else {
            throw OpenAITTSError.invalidResponse
        }
        
        print("[OpenAI TTS Request] Text length: \(text.count) chars")
        print("[OpenAI TTS Request] Voice: \(selectedVoice.rawValue)")
        print("[OpenAI TTS Request] Model: \(selectedModel.rawValue)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": selectedModel.rawValue,
            "input": text,
            "voice": selectedVoice.rawValue,
            "response_format": responseFormat
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAITTSError.invalidResponse
            }
            
            print("[OpenAI TTS Response] Status code: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                if data.isEmpty {
                    throw OpenAITTSError.invalidAudioData
                }
                print("[OpenAI TTS Success] Received \(data.count) bytes of audio")
                return data
                
            case 429:
                print("[OpenAI TTS Error] Rate limited")
                throw OpenAITTSError.rateLimited
                
            case 401:
                print("[OpenAI TTS Error] Invalid API key")
                throw OpenAITTSError.networkError("Invalid API key")
                
            case 403:
                print("[OpenAI TTS Error] Access denied")
                throw OpenAITTSError.networkError("Access denied. Check your API key permissions.")
                
            case 400:
                let errorMessage = parseErrorResponse(data)
                print("[OpenAI TTS Error 400] \(errorMessage)")
                throw OpenAITTSError.networkError("API Error: \(errorMessage)")
                
            case 402:
                print("[OpenAI TTS Error] Quota exceeded")
                throw OpenAITTSError.quotaExceeded
                
            case 500...599:
                let errorMessage = parseErrorResponse(data)
                print("[OpenAI TTS Error \(httpResponse.statusCode)] \(errorMessage)")
                throw OpenAITTSError.networkError("Server error (\(httpResponse.statusCode))")
                
            default:
                let errorMessage = parseErrorResponse(data)
                print("[OpenAI TTS Error \(httpResponse.statusCode)] \(errorMessage)")
                throw OpenAITTSError.networkError("Error (\(httpResponse.statusCode)): \(errorMessage)")
            }
        } catch let error as OpenAITTSError {
            throw error
        } catch {
            throw OpenAITTSError.networkError(error.localizedDescription)
        }
    }
    
    /// Combine multiple WAV files into a single WAV file
    private func combineWAVFiles(_ wavFiles: [Data]) -> Data {
        guard !wavFiles.isEmpty else { return Data() }
        guard wavFiles.count > 1 else { return wavFiles[0] }
        
        // Extract PCM data from each WAV file (skip 44-byte header)
        var combinedPCM = Data()
        for wavData in wavFiles {
            guard wavData.count > 44 else { continue }
            let pcmData = wavData.dropFirst(44)
            combinedPCM.append(pcmData)
        }
        
        // Create new WAV file with combined PCM data
        return createWAVHeader(for: combinedPCM, sampleRate: 24000) + combinedPCM
    }
    
    /// Create a WAV header for the given PCM data
    private func createWAVHeader(for pcmData: Data, sampleRate: Int) -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        
        let dataSize = Int32(pcmData.count)
        let fileSize = 36 + dataSize
        
        var wavHeader = Data()
        
        // RIFF header
        wavHeader.append("RIFF".data(using: .ascii)!)
        wavHeader.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        wavHeader.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavHeader.append("fmt ".data(using: .ascii)!)
        wavHeader.append(contentsOf: withUnsafeBytes(of: Int32(16).littleEndian) { Array($0) })
        wavHeader.append(contentsOf: withUnsafeBytes(of: Int16(1).littleEndian) { Array($0) })
        wavHeader.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        wavHeader.append(contentsOf: withUnsafeBytes(of: Int32(sampleRate).littleEndian) { Array($0) })
        
        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample) / 8
        wavHeader.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        
        let blockAlign = numChannels * bitsPerSample / 8
        wavHeader.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        wavHeader.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })
        
        // data chunk
        wavHeader.append("data".data(using: .ascii)!)
        wavHeader.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })
        
        return wavHeader
    }
    
    /// Check if service is configured
    var isConfigured: Bool {
        !apiKey.isEmpty
    }
    
    /// Parse error response from API
    private func parseErrorResponse(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let message = json["message"] as? String {
                return message
            }
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - API Key Config

private struct OpenAIKeyConfig: Codable {
    let openaiAPIKey: String?
    
    enum CodingKeys: String, CodingKey {
        case openaiAPIKey = "openai_api_key"
    }
}
