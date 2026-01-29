// TTSManager.swift
// FlowRead - Unified TTS Manager that coordinates between different TTS engines

import Foundation
import Combine

/// Unified TTS Manager that handles multiple TTS engines
@MainActor
class TTSManager: ObservableObject {
    
    // MARK: - TTS Services
    private let nativeTTS: NativeTTSService
    private let groqTTS: GroqTTSService

    private let piperTTS: PiperTTSService
    
    // MARK: - Current Engine
    @Published private(set) var currentEngine: TTSEngine = .macOSNative
    @Published private(set) var lastError: String?
    
    // MARK: - Voice Settings
    private var nativeVoice: NativeVoice = .samantha
    private var groqVoice: GroqVoice = .hannah

    private var piperVoice: PiperVoice = .amy_medium
    
    // MARK: - Initialization
    init(groqService: GroqTTSService) {
        logDebug("TTSManager: Initializing NativeTTSService...")
        self.nativeTTS = NativeTTSService()

        logDebug("TTSManager: Setting GroqTTSService...")
        self.groqTTS = groqService



        logDebug("TTSManager: Initializing PiperTTSService...")
        self.piperTTS = PiperTTSService()

        logInfo("TTSManager initialized with macOS Native as default engine")
    }
    
    // MARK: - Engine Selection
    
    func setEngine(_ engine: TTSEngine) {
        self.currentEngine = engine
        self.lastError = nil
        print("[TTSManager] Engine switched to: \(engine.displayName)")
    }
    
    func getEngine() -> TTSEngine {
        return currentEngine
    }
    
    // MARK: - Voice Selection
    
    func setNativeVoice(_ voice: NativeVoice) {
        self.nativeVoice = voice
        nativeTTS.setVoice(voice)
    }
    
    func setGroqVoice(_ voice: GroqVoice) async {
        self.groqVoice = voice
        await groqTTS.setVoice(voice)
    }
    


    func setPiperVoice(_ voice: PiperVoice) {
        self.piperVoice = voice
        piperTTS.setVoice(voice)
    }
    
    func getNativeVoice() -> NativeVoice { nativeVoice }
    func getGroqVoice() -> GroqVoice { groqVoice }

    func getPiperVoice() -> PiperVoice { piperVoice }
    
    // MARK: - Synthesize
    
    /// Synthesize text to audio using the currently selected engine
    func synthesize(text: String) async throws -> Data? {
        lastError = nil

        logInfo("TTSManager: Synthesizing with \(currentEngine.displayName)...")
        logDebug("TTSManager: Text length: \(text.count) characters")

        do {
            switch currentEngine {
            case .macOSNative:
                logInfo("TTSManager: Using macOS Native TTS")
                return try await synthesizeWithNative(text: text)
            case .groqAPI:
                logInfo("TTSManager: Using Groq API TTS")
                return try await synthesizeWithGroq(text: text)

            case .piper:
                logInfo("TTSManager: Using Piper TTS")
                return try await synthesizeWithPiper(text: text)
            }
        } catch {
            lastError = error.localizedDescription
            logError("TTSManager: Synthesis error - \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Check if the current engine is ready to use
    func isEngineReady() -> Bool {
        switch currentEngine {
        case .macOSNative:
            return true  // Always ready
        case .groqAPI:
            return true  // Keys are checked when synthesizing

        case .piper:
            // Check if at least one voice is downloaded
            let amyExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .amy_medium).path)
            let ryanExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .ryan_medium).path)
            return amyExists || ryanExists
        }
    }
    
    /// Check if text is valid for TTS
    func isValidForTTS(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return false }
        guard trimmed.count >= 2 else { return false }
        
        // Check for meaningful content
        let hasLetters = trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        if !hasLetters { return false }
        
        return true
    }
    
    // MARK: - Private Synthesis Methods
    
    private func synthesizeWithNative(text: String) async throws -> Data? {
        do {
            let audioData = try await nativeTTS.synthesize(text: text)
            if let data = audioData {
                logInfo("TTSManager: Native TTS returned \(data.count) bytes")
            }
            return audioData
        } catch {
            logError("TTSManager: Native TTS failed - \(error.localizedDescription)")
            throw error
        }
    }
    
    private func synthesizeWithGroq(text: String) async throws -> Data? {
        return try await groqTTS.synthesize(text: text)
    }
    

    
    private func synthesizeWithPiper(text: String) async throws -> Data? {
        logInfo("TTSManager: Attempting Piper synthesis...")
        do {
            let audioData = try await piperTTS.synthesize(text: text)
            if let data = audioData {
                logInfo("TTSManager: ✓ Piper TTS returned \(data.count) bytes")
            }
            return audioData
        } catch {
            logWarning("TTSManager: ⚠️ Piper TTS failed - \(error.localizedDescription)")
            logInfo("TTSManager: Falling back to macOS Native TTS")
            lastError = "Piper failed: \(error.localizedDescription) - Using macOS Native instead"
            return try await synthesizeWithNative(text: text)
        }
    }
    
    // MARK: - Engine Information
    
    /// Get human-readable status for the current engine
    func getEngineStatus() -> String {
        switch currentEngine {
        case .macOSNative:
            return "Ready - Using \(nativeVoice.displayName)"
        case .groqAPI:
            return "Ready - Using \(groqVoice.displayName)"
        case .piper:
            let amyExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .amy_medium).path)
            let ryanExists = FileManager.default.fileExists(atPath: ModelDownloadManager.piperModelPath(for: .ryan_medium).path)
            if amyExists || ryanExists {
                return "Ready - Using \(piperVoice.displayName)"
            } else {
                return "Model Download Required"
            }
        }
    }
    
    // MARK: - Reload API Keys (for Groq)
    
    func reloadGroqKeys() async {
        await groqTTS.reloadKeys()
    }
}

// MARK: - GroqTTSService Extension for API Key Check

extension GroqTTSService {
    func hasAPIKeys() async -> Bool {
        // The service handles key management internally
        return true
    }
}
