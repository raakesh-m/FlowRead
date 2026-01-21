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

/// Available Groq TTS voices
enum GroqVoice: String, CaseIterable, Identifiable {
    case aura = "aura-asteria-en"
    case ember = "aura-athena-en"
    case orbit = "aura-luna-en"
    case arcas = "aura-arcas-en"
    case helios = "aura-helios-en"
    case zeus = "aura-zeus-en"
    case hera = "aura-hera-en"
    case orion = "aura-orion-en"
    case perseus = "aura-perseus-en"
    case angus = "aura-angus-en"
    case orpheus = "aura-orpheus-en"
    case stella = "aura-stella-en"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.replacingOccurrences(of: "aura-", with: "")
            .replacingOccurrences(of: "-en", with: "")
            .capitalized
    }
}

/// Manages Groq TTS API calls with automatic key rotation
actor GroqTTSService {
    private var apiKeys: [String] = []
    private var currentKeyIndex: Int = 0
    private var failedKeys: Set<Int> = []
    
    private let baseURL = "https://api.groq.com/openai/v1/audio/speech"
    private var selectedVoice: GroqVoice = .aura
    
    private let session: URLSession
    
    // Audio response format
    private let responseFormat = "mp3"
    
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
    func synthesize(text: String) async throws -> Data {
        guard !apiKeys.isEmpty else {
            throw GroqTTSError.noAPIKeysConfigured
        }
        
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
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "playht-tts",
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
            
            switch httpResponse.statusCode {
            case 200:
                if data.isEmpty {
                    throw GroqTTSError.invalidAudioData
                }
                return data
                
            case 429:
                throw GroqTTSError.rateLimited
                
            case 401, 403:
                throw GroqTTSError.networkError("Invalid or expired API key")
                
            case 400:
                throw GroqTTSError.networkError("Bad request - text may be too long or invalid")
                
            case 500...599:
                throw GroqTTSError.networkError("Server error (\(httpResponse.statusCode))")
                
            default:
                throw GroqTTSError.networkError("Unexpected status code: \(httpResponse.statusCode)")
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
}

// MARK: - API Key Config

private struct APIKeyConfig: Codable {
    let groqAPIKeys: [String]
    
    enum CodingKeys: String, CodingKey {
        case groqAPIKeys = "groq_api_keys"
    }
}
